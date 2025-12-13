# Customer Churn & Retention Analysis

## Project Overview
This project analyzes customer purchasing behavior to identify churn patterns,
segment customers using RFM analysis, and predict churn risk using machine learning.
The final output is an interactive Power BI dashboard designed to support
data-driven retention strategies.

## Business Problem
Customer churn leads to revenue instability and inefficient marketing spend.
The business lacks visibility into which customers are likely to churn and why.
This project addresses that gap by combining SQL analytics, customer segmentation,
and predictive modeling.

## Tools & Technologies
- Python (Pandas, Scikit-learn, SHAP)
- MySQL (SQL analytics & views)
- Power BI (Interactive dashboards)
- Machine Learning (Random Forest)
- GitHub (Version control)

## Key Analysis Performed
- Data cleaning and customer-level aggregation
- KPI calculation (AOV, churn rate, repeat purchase rate)
- RFM segmentation and cohort retention analysis
- Churn prediction using machine learning
- Revenue-at-risk identification

## Dashboard Overview
The Power BI dashboard contains:
- Customer and revenue overview
- RFM segment distribution
- Cohort retention heatmap
- Churn probability analysis
- At-risk customer identification

## Repository Structure
- notebook/ → Python analysis and ML modeling
- sql/ → SQL queries, views, and analytics logic
- dashboard/ → Power BI dashboard screenshots
- presentation/ → Project presentation
- report/ → Detailed project report

## Business Impact
- Identifies At-Risk and Lost customers using RFM-based behavioral patterns
- Quantifies revenue concentration across customer segments to prioritize retention efforts
- Highlights cohort-level retention drop-offs to inform lifecycle interventions
- Enables targeted, data-driven retention actions supported by churn probability scores
