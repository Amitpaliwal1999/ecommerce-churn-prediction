# E-Commerce Customer Churn Prediction

## Project Overview
This project analyzes e-commerce customer data to identify the key factors driving customer churn and to predict which customers are likely to leave. The analysis was performed using SQL for data querying, Python in Google Colab for exploratory analysis and machine learning, and insights were visualized using Power BI dashboards.

## Tools & Technologies
- MySQL Workbench
- Python
- Pandas
- NumPy
- Scikit-learn / XGBoost
- Google Colab
- Power BI

## Dataset
The dataset contains e-commerce customer data including:
- Customer ID and demographics
- Tenure
- Preferred login device and payment mode
- Preferred order category
- Satisfaction score
- Complaint status
- Order count and coupon usage
- Cashback amount
- Days since last order
- Churn status

## Project Workflow
1. Imported dataset into MySQL Workbench for initial querying and aggregation
2. Loaded and cleaned data in Google Colab (handled missing values, removed duplicates)
3. Performed exploratory data analysis using Pandas and visualization libraries
4. Engineered features such as RFM scores, engagement score, and risk flags
5. Trained and compared Random Forest, Gradient Boosting, and XGBoost models
6. Selected XGBoost as the final model based on ROC-AUC and false negative rate
7. Exported churn scores and processed data
8. Built six interactive Power BI dashboards

## Dashboard Layout

### KPIs
- Total Customers
- Churn Rate %
- Churned Customers
- Retention Rate %
- Revenue at Risk

### Charts
- Churn Rate by Complaint Status
- Churn Rate by Payment Mode
- Churn Rate by Order Category
- Customer Retention Funnel by Tenure
- Churn Rate Across Customer Lifecycle
- CLV Segment Distribution and Revenue by Segment
- RFM Segment Summary (Champions, Loyal, At Risk, Hibernating, Lost)
- Purchase Frequency vs Churn Rate
- Churn Score Distribution and Risk Tier Breakdown

### Filters
- Churn Status
- CLV Segment
- Risk Label
- Tenure Band
- Marital Status
- Preferred Order Category

## Key Insights
- Tenure is the strongest predictor of churn — new customers (0–1 month) churn at over 50%, while customers with 2+ years of tenure churn at 0%.
- Customers who file complaints churn at nearly 3x the rate of those who don't.
- Mobile phone buyers show the highest category churn rate, while grocery buyers show the lowest.
- App engagement time is a strong early-warning signal — low engagement precedes churn.
- High-value customer segments (Champions, Loyal) are churning at or above the platform average, signalling a need for differentiated retention treatment.

## Project Structure
```
ecommerce-churn-prediction
│
├── sql
│   └── ecommerce.sql
│
├── notebooks
│   └── ecommerce_churn_project.ipynb
│
├── data
│   ├── E_Commerce_Dataset For MYSQL.xlsx
│   ├── E_Commerce_Dataset For POWERBI.xlsx
│   └── ecommerce_clean For Python.csv
│
└── dashboards
    └── ecommerce_churn_dashboard.pbix
```
