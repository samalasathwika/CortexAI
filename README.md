# Cortex AI – Intelligent Personal Money-Balancing & Financial Decision-Support System

Cortex AI is a personal finance and lifestyle decision-support platform designed to help students and working professionals manage their income, expenses, savings, financial goals, and lifestyle choices.

The system analyzes a user's financial situation, calculates disposable income, and generates personalized budget allocation recommendations based on financial goals, risk preferences, and lifestyle choices.

🌐 **Live Demo:** https://cortex-ai-frontend-ivory.vercel.app/

📖 **Backend API Documentation:** https://cortex-ai-backend-uevq.onrender.com/docs

---

## 🚀 Key Features

- **User Authentication:** Secure registration, login, profile management, and password recovery.
- **Income & Expense Management:** Record monthly income and expenses to understand available funds.
- **Smart Budget Planning:** Calculate disposable income after accounting for essential expenses.
- **Personalized Recommendations:** Generate financial allocation suggestions based on user preferences and financial goals.
- **Financial Goals:** Set savings goals and manage financial priorities.
- **Risk-Based Planning:** Consider different risk preferences while generating allocation strategies.
- **Financial History:** Review previous financial plans and monthly financial analysis.
- **Lifestyle Recommendations:** Explore movie and shopping recommendations based on lifestyle preferences and available budgets.
- **Interactive Dashboard:** View financial summaries and manage personal financial information through a user-friendly interface.
- **Progressive Web App:** Frontend includes PWA support through a web manifest and service worker.

## 🛠️ Technology Stack

| Component | Technologies |
|---|---|
| Frontend | HTML, CSS, JavaScript |
| Backend | Python, FastAPI |
| Database | MySQL 8.0 |
| ORM | SQLAlchemy |
| Authentication | JWT, Passlib |
| API Documentation | Swagger / OpenAPI |
| External Integration | OMDb API |
| Deployment | Vercel, Render |

## 🏗️ System Architecture

```text
             USER
               |
               v
       CORTEX AI FRONTEND
        (HTML, CSS, JS)
               |
          REST API
               |
               v
        FASTAPI BACKEND
               |
       +-------+--------+
       |       |        |
       v       v        v
    AUTH   FINANCIAL  RECOMMENDATION
   MODULE   MODULE      ENGINE
       |       |        |
       +-------+--------+
               |
               v
          MYSQL DATABASE
               |
               v
       PERSONALIZED RESULTS
               |
               v
          USER DASHBOARD
```

## 📂 Project Structure

```text
CortexAI/
│
├── backend/
│   ├── app/
│   │   ├── routers/
│   │   │   ├── auth_router.py
│   │   │   ├── budget_router.py
│   │   │   ├── goals_router.py
│   │   │   ├── recommendation_router.py
│   │   │   ├── plans_router.py
│   │   │   └── lifestyle_router.py
│   │   │
│   │   ├── services/
│   │   │   ├── recommendation_engine.py
│   │   │   ├── omdb_service.py
│   │   │   ├── shopping_service.py
│   │   │   └── real_world_rec_service.py
│   │   │
│   │   ├── auth.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── init_db.py
│   │   ├── main.py
│   │   ├── models.py
│   │   └── schemas.py
│   │
│   ├── .env.example
│   ├── requirements.txt
│   └── run.py
│
├── database/
│   └── cortex-ai-database/
│       ├── schema.sql
│       ├── seed.sql
│       ├── queries.sql
│       ├── security.sql
│       ├── test_database.sql
│       ├── er_diagram.mmd
│       ├── data_dictionary.md
│       └── deployment_guide.md
│
├── frontend/
│   ├── index.html
│   ├── manifest.json
│   ├── sw.js
│   ├── icon-192.png
│   └── icon-512.png
│
├── .gitignore
└── README.md
```

## ⚙️ Installation & Setup

Follow these steps to run Cortex AI locally.

### Prerequisites

- Python 3.10 or above
- MySQL Server 8.0
- Git
- Web browser

### 1. Clone the Repository

```bash
git clone https://github.com/samalasathwika/CortexAI.git
cd CortexAI
```

### 2. Set Up the Database

1. Open MySQL Workbench.
2. Connect to your MySQL server.
3. Open `database/cortex-ai-database/schema.sql`.
4. Execute the schema script.
5. Execute `seed.sql` to load sample data.

**Note:** Review `schema.sql` before execution. It contains a database drop-and-recreate operation and can delete an existing database with the same name.

### 3. Configure Environment Variables

Navigate to the backend folder:

```bash
cd backend
```

Create a `.env` file using `.env.example` as a template.

Configure your local MySQL credentials and generate your own secure JWT secret.

Example:

```env
PORT=8000
HOST=127.0.0.1
SECRET_KEY=your-own-secret-key

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=your-mysql-password
MYSQL_DATABASE=cortex_ai
```

Never upload your actual `.env` file or API credentials to GitHub.

### 4. Install Dependencies

```bash
pip install -r requirements.txt
```

### 5. Start the Backend

```bash
python run.py
```

The backend will start at:

```text
http://127.0.0.1:8000
```

API documentation:

```text
http://127.0.0.1:8000/docs
```

The FastAPI application also serves the frontend when running locally.

## 🔗 API Modules

| Module | Functionality |
|---|---|
| Authentication | Registration, login, profile and password management |
| Budget | Monthly income and expense management |
| Goals | Financial goals and user preferences |
| Recommendations | Personalized financial recommendations |
| Plans | Financial plans, history and analysis |
| Lifestyle | Movie and shopping recommendations |

## 🗄️ Database

Cortex AI uses a MySQL relational database to organize and manage financial information.

The database documentation includes:

- Database schema
- Entity Relationship Diagram
- Data dictionary
- SQL queries
- Security scripts
- Sample data
- Database testing scripts

Explore the `database/cortex-ai-database/` directory for detailed documentation.

## 🌐 Deployment

The project has an existing deployed version that can be accessed through the following links:

- **Frontend:** https://cortex-ai-frontend-ivory.vercel.app/
- **Backend:** https://cortex-ai-backend-uevq.onrender.com/
- **API Documentation:** https://cortex-ai-backend-uevq.onrender.com/docs

The live deployment is hosted separately from this GitHub repository.

## 🔮 Future Enhancements

- Integration of advanced machine-learning-based financial recommendations.
- Real-time financial market data integration.
- Improved financial analytics and visualization.
- Enhanced savings goal tracking.
- More personalized lifestyle and shopping recommendations.
- Improved mobile experience.

## 👩‍💻 Project Contributors

This is a collaborative group project developed as part of our academic work.

- Samala Sathwika
- Thallapally Arsha
- Burra Sruthi
- Thulasi ShylaSri
- Hepsiba Devara

## 📜 License

This project is developed for educational and academic purposes.

---

**Cortex AI – Making smarter financial decisions, one step at a time.**
