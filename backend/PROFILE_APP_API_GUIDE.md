# Profile App API Guide

Complete guide for testing the `profile_app` endpoints in Postman.

---

## 📋 Table of Contents
1. [API Base URL](#api-base-url)
2. [Authentication](#authentication)
3. [Endpoints Overview](#endpoints-overview)
4. [Profile Endpoints](#profile-endpoints)
5. [Achievement Endpoints](#achievement-endpoints)
6. [Postman Setup](#postman-setup)
7. [Error Responses](#error-responses)

---

## 🔗 API Base URL

```
http://localhost:8000/api/profile/
```

---

## 🔐 Authentication

All endpoints require authentication using a **Bearer Token**.

### How to Get a Token
1. Create a user or login
2. Get your authentication token from the login endpoint
3. Use it in the `Authorization` header

### Header Format
```
Authorization: Bearer <your-token-here>
```

---

## 📊 Endpoints Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/profile/profile/` | Fetch logged-in user's profile |
| PUT | `/api/profile/profile/` | Update user profile (name, phone) |
| GET | `/api/profile/achievements/` | List all user's achievements |
| POST | `/api/profile/achievements/` | Create a new achievement |
| GET | `/api/profile/achievements/{id}/` | Fetch a specific achievement |
| PUT | `/api/profile/achievements/{id}/` | Update an achievement |
| DELETE | `/api/profile/achievements/{id}/` | Delete an achievement |

---

## 👤 Profile Endpoints

### 1. **GET Profile** - Fetch Logged-in User's Profile

#### **View Mode (Default):**
**Endpoint:**
```
GET /api/profile/profile/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**No Body Required**

#### **Edit Mode (Optimized for Editing):**
**Endpoint:**
```
GET /api/profile/profile/?edit=true
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**No Body Required**

**Edit Mode Response (200 OK):**
```json
{
  "message": "Profile fetched for editing.",
  "profile": {
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1234567890",
    "interested_sports": [1, 2],
    "avatar_id": "avatar_12",
    "teams": [...],
    "achievements": [...]
  }
}
```

**Note:** Edit mode returns `interested_sports` as an array of sport IDs (not objects) for easier form handling.

**Success Response (200 OK):**
```json
{
  "message": "Profile fetched successfully.",
  "profile": {
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1234567890",
    "interested_sports": [
      { "id": 1, "sport_name": "Tennis" },
      { "id": 2, "sport_name": "Cricket" }
    ],
    "avatar_id": "avatar_12",
    "teams": [
      {
        "team_name": "Tennis Titans",
        "sport": "Tennis",
        "captain_name": "John Doe",
        "created_on": "2025-11-20T10:30:00Z"
      },
      {
        "team_name": "Cricket Stars",
        "sport": "Cricket",
        "captain_name": "Alice Smith",
        "created_on": "2025-11-15T14:25:00Z"
      }
    ],
    "achievements": [
      {
        "id": 1,
        "sport": "Tennis",
        "title": "District Champion",
        "year": 2024,
        "achievement": "Won District Tennis Tournament",
        "experience": "Defeated 15 opponents"
      },
      {
        "id": 2,
        "sport": "Cricket",
        "title": "Best Batsman",
        "year": 2023,
        "achievement": "Highest run scorer in college",
        "experience": "Score: 450 runs in 10 matches"
      }
    ]
  }
}
```

---

### 2. **PUT Profile** - Update User Profile

**Endpoint:**
```
PUT /api/profile/profile/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**Request Body (All fields required):**
```json
{
  "name": "John Smith",
  "phone": "+9876543210",
  "interested_sports": [1, 2],
  "avatar_id": "avatar_12"
}
```

**Field Requirements:**
- `name` *(required)* - User's full name (cannot be empty)
- `phone` *(required)* - Phone number (cannot be empty)
- `interested_sports` *(required)* - List of sport IDs (minimum 1 sport required)
- `avatar_id` *(required)* - Avatar identifier (cannot be empty)

**Note:** Both fields are optional. Send only the fields you want to update.

**Alternative Request (Update Only Name):**
```json
{
  "name": "John Smith"
}
```

**Alternative Request (Update Only Phone):**
```json
{
  "phone": "+9876543210"
}
```

**Success Response (200 OK):**
```json
{
  "message": "Profile updated successfully.",
  "profile": {
    "name": "John Smith",
    "email": "john@example.com",
    "phone": "+9876543210",
    "interested_sports": [
      { "id": 1, "sport_name": "Tennis" }
    ],
    "avatar_id": "avatar_12",
    "teams": [
      {
        "team_name": "Tennis Titans",
        "sport": "Tennis",
        "captain_name": "John Smith",
        "created_on": "2025-11-20T10:30:00Z"
      }
    ],
    "achievements": [
      {
        "id": 1,
        "sport": "Tennis",
        "title": "District Champion",
        "year": 2024,
        "achievement": "Won District Tennis Tournament",
        "experience": "Defeated 15 opponents"
      }
    ]
  }
}
```

---

## 🏆 Achievement Endpoints

### 3. **GET Achievements** - List All User's Achievements

**Endpoint:**
```
GET /api/profile/achievements/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**Query Parameters (Optional):**
```
?ordering=-year    # Sort by year (newest first)
```

**No Body Required**

**Success Response (200 OK):**
```json
[
  {
    "id": 1,
    "sport": "Tennis",
    "title": "District Champion",
    "year": 2024,
    "achievement": "Won District Tennis Tournament",
    "experience": "Defeated 15 opponents"
  },
  {
    "id": 2,
    "sport": "Cricket",
    "title": "Best Batsman",
    "year": 2023,
    "achievement": "Highest run scorer in college",
    "experience": "Score: 450 runs in 10 matches"
  }
]
```

---

### 4. **POST Achievement** - Create a New Achievement

**Endpoint:**
```
POST /api/profile/achievements/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**Request Body:**
```json
{
  "sport": "Basketball",
  "title": "MVP Player",
  "year": 2025,
  "achievement": "Named MVP in College Tournament",
  "experience": "Led team to finals with 25 points per game"
}
```

**Field Descriptions:**
- `sport` *(required)* - Sport name (e.g., Tennis, Cricket, Football, Basketball)
- `title` *(required)* - Achievement title/award name
- `year` *(required)* - Year of achievement (integer)
- `achievement` *(required)* - Description of the achievement
- `experience` *(optional)* - Additional details/experience

**Success Response (201 Created):**
```json
{
  "id": 3,
  "sport": "Basketball",
  "title": "MVP Player",
  "year": 2025,
  "achievement": "Named MVP in College Tournament",
  "experience": "Led team to finals with 25 points per game"
}
```

---

### 5. **GET Achievement** - Fetch Specific Achievement

**Endpoint:**
```
GET /api/profile/achievements/{id}/
```

**Example:**
```
GET /api/profile/achievements/1/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**No Body Required**

**Success Response (200 OK):**
```json
{
  "id": 1,
  "sport": "Tennis",
  "title": "District Champion",
  "year": 2024,
  "achievement": "Won District Tennis Tournament",
  "experience": "Defeated 15 opponents"
}
```

---

### 6. **PUT Achievement** - Update an Achievement

**Endpoint:**
```
PUT /api/profile/achievements/{id}/
```

**Example:**
```
PUT /api/profile/achievements/1/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**Request Body:**
```json
{
  "title": "National Champion",
  "experience": "Won National Tournament against top players"
}
```

**Note:** Send only the fields you want to update.

**Success Response (200 OK):**
```json
{
  "id": 1,
  "sport": "Tennis",
  "title": "National Champion",
  "year": 2024,
  "achievement": "Won District Tennis Tournament",
  "experience": "Won National Tournament against top players"
}
```

---

### 7. **DELETE Achievement** - Delete an Achievement

**Endpoint:**
```
DELETE /api/profile/achievements/{id}/
```

**Example:**
```
DELETE /api/profile/achievements/1/
```

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <your-token>"
}
```

**No Body Required**

**Success Response (204 No Content):**
```
(Empty response - achievement deleted)
```

---

## 🧪 Postman Setup

### Step 1: Create a New Collection
1. Open Postman
2. Click **"New"** → **"Collection"**
3. Name it: `Profile App Tests`

### Step 2: Set Environment Variables
1. Click **"Environments"** → **"+"**
2. Name it: `Local Development`
3. Add variables:
   - `base_url` = `http://localhost:8000/api`
   - `token` = `<your-bearer-token>`
   - `achievement_id` = `1`

### Step 3: Create Requests

#### Request 1: Get Profile
- **Method:** GET
- **URL:** `{{base_url}}/profile/profile/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Send**

#### Request 2: Update Profile
- **Method:** PUT
- **URL:** `{{base_url}}/profile/profile/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Body Tab:** Raw, JSON
  ```json
  {
    "name": "Updated Name",
    "phone": "+9999999999"
  }
  ```
- **Send**

#### Request 3: List Achievements
- **Method:** GET
- **URL:** `{{base_url}}/profile/achievements/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Send**

#### Request 4: Create Achievement
- **Method:** POST
- **URL:** `{{base_url}}/profile/achievements/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Body Tab:** Raw, JSON
  ```json
  {
    "sport": "Football",
    "title": "Gold Medalist",
    "year": 2024,
    "achievement": "Won Gold in National Championships",
    "experience": "Outstanding performance in all 5 matches"
  }
  ```
- **Send**

#### Request 5: Get Single Achievement
- **Method:** GET
- **URL:** `{{base_url}}/profile/achievements/{{achievement_id}}/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Send**

#### Request 6: Update Achievement
- **Method:** PUT
- **URL:** `{{base_url}}/profile/achievements/{{achievement_id}}/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Body Tab:** Raw, JSON
  ```json
  {
    "title": "Platinum Medalist",
    "experience": "Exceptional performance - set new record"
  }
  ```
- **Send**

#### Request 7: Delete Achievement
- **Method:** DELETE
- **URL:** `{{base_url}}/profile/achievements/{{achievement_id}}/`
- **Headers Tab:**
  - Key: `Authorization`, Value: `Bearer {{token}}`
- **Send**

---

## ❌ Error Responses

### 1. **Unauthorized (401)**
```json
{
  "detail": "Authentication credentials were not provided."
}
```
**Cause:** Missing or invalid token
**Solution:** Add valid token to Authorization header

### 2. **Not Found (404)**
```json
{
  "detail": "Not found."
}
```
**Cause:** Achievement with given ID doesn't exist
**Solution:** Verify the achievement ID

### 3. **Bad Request (400)**
```json
{
  "field_name": [
    "This field is required."
  ]
}
```
**Cause:** Missing required field in request body
**Solution:** Include all required fields

### 4. **Validation Error (400)**
```json
{
  "phone": [
    "Ensure this field has no more than 30 characters."
  ]
}
```
**Cause:** Invalid field value
**Solution:** Check field constraints and data types

---

## 🔍 Testing Checklist

- [ ] Get profile successfully
- [ ] Update profile (name and phone)
- [ ] List all achievements
- [ ] Create a new achievement
- [ ] Get single achievement by ID
- [ ] Update an achievement
- [ ] Delete an achievement
- [ ] Verify authentication errors
- [ ] Verify validation errors
- [ ] Check all responses have correct status codes

---

## 📞 Support & Debugging

**Common Issues:**

1. **401 Unauthorized**
   - Ensure you have a valid token
   - Check token is not expired
   - Include `Bearer` prefix in Authorization header

2. **404 Not Found**
   - Verify the achievement ID exists
   - Check the URL spelling

3. **Empty Achievements List**
   - Create some achievements first using POST endpoint
   - User may not have any achievements yet

4. **Profile Teams/Achievements Empty**
   - Create teams and achievements first
   - Ensure user is a member of teams

---

## 📝 Notes

- All timestamps are in UTC (ISO 8601 format)
- Achievements are automatically sorted by year (newest first)
- Only authenticated users can access these endpoints
- Users can only see and modify their own profile and achievements
- Profile is auto-created when a user is created
