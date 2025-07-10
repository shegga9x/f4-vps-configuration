from sentence_transformers import SentenceTransformer, util
import numpy as np
import json
from fastapi import FastAPI, Query
from fastapi.responses import JSONResponse
from typing import List

# Load courses from JSON file
with open("./course.json", "r") as f:
    courses = json.load(f)

# Convert course object to flat text
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

# Load model
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
embeddings = model.encode(texts, convert_to_tensor=True)

def recommend_courses(course_id: str, top_k: int = 5):
    target_index = next((i for i, c in enumerate(courses) if c.get('id') == course_id), None)
    if target_index is None:
        return []
    target_embedding = embeddings[target_index]
    cos_scores = util.pytorch_cos_sim(target_embedding, embeddings)[0]
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

def chat_response(user_query: str, top_k: int = 3):
    query_embedding = model.encode(user_query, convert_to_tensor=True)
    cos_scores = util.pytorch_cos_sim(query_embedding, embeddings)[0]
    sorted_indices = np.argsort(-cos_scores)
    responses = []
    seen = set()
    for idx in sorted_indices:
        course = courses[idx]
        title = course["title"]
        if title not in seen:
            responses.append({
                "id": course["id"],
                "title": title,
                "description": course["description"],
                "score": float(cos_scores[idx])
            })
            seen.add(title)
        if len(responses) >= top_k:
            break
    return responses

# FastAPI setup
app = FastAPI()

@app.get("/recommend")
def recommend(course_id: str, top_k: int = 5):
    recs = recommend_courses(course_id, top_k)
    return JSONResponse(content=recs)

@app.post("/recommend/batch")
def recommend_batch(course_ids: List[str] = Query(...), top_k: int = 5):
    result = {cid: recommend_courses(cid, top_k) for cid in course_ids}
    return JSONResponse(content=result)

@app.get("/chat")
def chat(query: str, top_k: int = 3):
    """
    Chat endpoint that returns courses most related to a user's natural-language question.
    """
    recs = chat_response(query, top_k)
    return JSONResponse(content=recs)

# Debug usage (CLI)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("recommend_courses:app", host="0.0.0.0", port=8000, reload=True)
