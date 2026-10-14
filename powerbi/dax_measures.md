# DAX Measures

All measures live in a dedicated `_Measures` table, grouped into display folders that follow the analysis path: Portfolio → Program → Cost Category → Month.

Model: `FactProgramFinancials` (864 rows) → `DimDate` (many-to-one on `reporting_month` = `Date`, single direction).

## 1. Core Cost

```dax
Total Budget Cost   = SUM ( FactProgramFinancials[budget_cost] )
Total Actual Cost   = SUM ( FactProgramFinancials[actual_cost] )
Total Earned Value  = SUM ( FactProgramFinancials[earned_value] )
Total Forecast Cost = SUM ( FactProgramFinancials[forecast_cost] )
```

## 2. Budget Variance

```dax
-- Positive = over budget (unfavorable)
Budget Variance = [Total Actual Cost] - [Total Budget Cost]

Budget Variance % = DIVIDE ( [Budget Variance], [Total Budget Cost] )
```

## 3. Earned Value

```dax
-- Negative = less work delivered than paid for (unfavorable)
Cost Variance = [Total Earned Value] - [Total Actual Cost]

-- Below 1.00 = unfavorable cost efficiency
CPI = DIVIDE ( [Total Earned Value], [Total Actual Cost] )
```

## 4. Variance Drivers

```dax
-- A cost category's share of its program's net budget variance
Share of Program Variance =
DIVIDE (
    [Budget Variance],
    CALCULATE ( [Budget Variance], REMOVEFILTERS ( FactProgramFinancials[cost_category] ) )
)

-- A program's share of the portfolio's NET budget variance (negative = offsets the overrun)
Share of Portfolio Variance =
DIVIDE (
    [Budget Variance],
    CALCULATE (
        [Budget Variance],
        REMOVEFILTERS ( FactProgramFinancials[program_name], FactProgramFinancials[cost_category] )
    )
)
```

## 5. Trend

```dax
-- Running total of budget variance through the month on the axis
Cumulative Budget Variance =
VAR CurrentDate = MAX ( DimDate[Date] )
RETURN
    CALCULATE ( [Budget Variance], REMOVEFILTERS ( DimDate ), DimDate[Date] <= CurrentDate )

-- First month after the last favorable month: the start of a sustained overrun
Sustained Overrun Start =
VAR MonthlyVariance =
    ADDCOLUMNS (
        CALCULATETABLE ( VALUES ( DimDate[Year Month Sort] ), REMOVEFILTERS ( DimDate ) ),
        "@Variance", CALCULATE ( [Budget Variance], ALLEXCEPT ( DimDate, DimDate[Year Month Sort] ) )
    )
VAR MonthsWithData = FILTER ( MonthlyVariance, NOT ISBLANK ( [@Variance] ) )
VAR LastFavorableMonth = MAXX ( FILTER ( MonthsWithData, [@Variance] <= 0 ), DimDate[Year Month Sort] )
VAR StartYM =
    IF (
        ISBLANK ( LastFavorableMonth ),
        MINX ( MonthsWithData, DimDate[Year Month Sort] ),
        MINX ( FILTER ( MonthsWithData, DimDate[Year Month Sort] > LastFavorableMonth ), DimDate[Year Month Sort] )
    )
RETURN
    IF ( NOT ISBLANK ( StartYM ), DATE ( INT ( StartYM / 100 ), MOD ( StartYM, 100 ), 1 ) )
```

## 6. Management Attention

```dax
-- Mirrors the SQL CASE logic: >= 2.5% High Attention, >= 1.0% Monitor, else On Track
Management Status =
VAR VariancePct = [Budget Variance %]
RETURN
    IF (
        NOT ISBLANK ( VariancePct ),
        SWITCH (
            TRUE (),
            VariancePct >= 0.025, "High Attention",
            VariancePct >= 0.01,  "Monitor",
            "On Track"
        )
    )

-- Earned-value flag shown beside Management Status; bands mirror the budget thresholds
CPI Watch =
VAR CurrentCPI = [CPI]
RETURN
    IF (
        NOT ISBLANK ( CurrentCPI ),
        SWITCH (
            TRUE (),
            CurrentCPI < 0.975, "Watch",
            CurrentCPI < 0.99,  "Monitor",
            "On Track"
        )
    )

-- Hex colors for conditional formatting (Format > Field value)
Management Status Color =
SWITCH ( [Management Status], "High Attention", "#C0392B", "Monitor", "#D68910", "On Track", "#1E8449" )

CPI Watch Color =
SWITCH ( [CPI Watch], "Watch", "#C0392B", "Monitor", "#D68910", "On Track", "#1E8449" )
```

Thresholds are illustrative choices for this project, not industry standards.
