from sentence_transformers import SentenceTransformer, util
import numpy as np
import json
from fastapi import FastAPI
from fastapi.responses import JSONResponse

# Load courses from JSON file
with open("./course.json", "r") as f:
    courses = json.load(f)

def course_to_text(c):
    return (
        f"ID: {c.get('id')}. Title: {c.get('title')}. Slug: {c.get('slug')}. "
        f"Description: {c.get('description')}. LongDescription: {c.get('longDescription')}. "
        f"ImageUrl: {c.get('imageUrl')}. Category: {c.get('category')}. Level: {c.get('level')}. "
        f"Price: {c.get('price')}. IsFeatured: {c.get('isFeatured')}. IsPopular: {c.get('isPopular')}. "
        f"EnrolledStudents: {c.get('enrolledStudents')}. Rating: {c.get('rating')}. ReviewCount: {c.get('reviewCount')}. "
        f"Language: {c.get('language')}. LastUpdated: {c.get('lastUpdated')}. AuthorId: {c.get('authorId')}. "
        f"Curriculum: {len(c.get('curriculum', []))} sections. "
        f"Requirements: {', '.join(c.get('requirements', []))}. "
        f"Objectives: {', '.join(c.get('objectives', []))}. "
        f"Tags: {', '.join(c.get('tags', []))}. "
        f"Quizzes: {len(c.get('quizzes', []))} quizzes. "
        f"Reviews: {len(c.get('reviews', []))} reviews."
    )

texts = [course_to_text(c) for c in courses]

# Load embedding model
model = SentenceTransformer("nomic-ai/nomic-embed-text-v1", trust_remote_code=True)
embeddings = model.encode(texts, convert_to_tensor=True)

def recommend_courses(course_id: str, top_k: int = 5):
    # Find the index of the course with the given id
    target_index = next((i for i, c in enumerate(courses) if c.get('id') == course_id), None)
    if target_index is None:
        print(f"Course with id '{course_id}' not found.")
        return []
    target_embedding = embeddings[target_index]
    cos_scores = util.pytorch_cos_sim(target_embedding, embeddings)[0]
    # Sort by similarity (descending), skip self
    sorted_indices = np.argsort(-cos_scores)
    seen_titles = set()
    recommendations = []
    for idx in sorted_indices:
        if idx == target_index:
            continue
        title = courses[idx]['title']
        if title not in seen_titles:
            recommendations.append({
                "id": courses[idx]['id'],
                "title": title,
                "score": float(cos_scores[idx])
            })
            seen_titles.add(title)
        if len(recommendations) >= top_k:
            break
    return recommendations

app = FastAPI()

@app.get("/recommend")
def recommend(course_id: str, top_k: int = 5):
    recs = recommend_courses(course_id, top_k)
    return JSONResponse(content=recs)

# Example usage:
if __name__ == "__main__":
    import uvicorn
    course_id = "c1"  # Change this to any course id you want to recommend for
    recs = recommend_courses(course_id)
    print(f"\nCourses similar to: {next(c['title'] for c in courses if c['id'] == course_id)}\n")
    for rec in recs:
        print(f"{rec['title']} (Score: {rec['score']:.4f})")
    # To run the API: uvicorn recommend_courses:app --reload
