# Findings

Analysis of the Superstore sample dataset: 9,994 order lines, 5,009 orders and 793 customers, January 2014 to December 2017. Every figure below comes from the PostgreSQL queries in `sql_queries/analysis_queries.sql` and was cross-checked against the Excel dashboard (built locally and not published; see the README).

## Headline numbers

| Sales | Profit | Margin |
|---|---|---|
| 2,297,200.86 | 286,397.02 | 12.47% |

## What the data shows

**1. Lines discounted by more than 20% are where the losses are.**
Order lines with no discount make a 29.51% margin on 1,087,908 in sales. Once a discount is added, the margin shrinks to 11.91% for discounts up to 20%. The 1,393 lines discounted by more than 20% have a margin of -37.32% and lose 135,376, a loss equal to about 47% of the profit the company reports. This holds in every region.

**2. Every loss-making state is a state where every line is discounted.**
Ten states lose money, 98,247 in total: Texas (-25,729), Ohio (-16,971), Pennsylvania (-15,560), Illinois (-12,608), North Carolina (-7,491), Colorado (-6,528), Tennessee (-5,342), Arizona (-3,428), Florida (-3,399) and Oregon (-1,190). All ten are among the 11 states where every order line carries a discount; the eleventh, Wyoming, barely breaks even (100). Those 11 states together have a margin of -13.88%, against 22.27% for states with mixed discounting and 29.81% for states with no discounts.

**3. Central's weakness comes from two states.**
Central has the lowest margin of the four regions (7.92%, against 14.94% in West), yet its margin on undiscounted sales is the highest (31.31%). The gap is Texas and Illinois, which lose 38,337 together and discount heavily (an average discount of 37% and 39%). The other 11 Central states are all profitable. In total, 643 of Central's 2,323 lines are discounted by more than 20% and lose 52,392.

**4. Three sub-categories lose money, mostly through discounting.**
Tables (-17,725), Bookcases (-3,473) and Supplies (-1,189) are unprofitable overall. Tables, Bookcases and Machines are strongly profitable without a discount (18.55%, 19.02% and 38.20%) and lose heavily above 20% (-34.13%, -38.88% and -38.46%). Machines sell 189,239 but earn only a 1.79% margin because 53 deeply discounted lines lose 29,555. Supplies is the exception: it is thin even without discounts (5.44%).

**5. Sales grow strongly and seasonally, but margin did not keep up in late 2017.**
Yearly sales were 484,248 (2014), 470,533 (2015), 609,206 (2016) and 733,215 (2017). Q4 is the peak every year and Q1 the low. Q4 2017 had the highest sales of any quarter (280,054) but a margin of 9.8%, against 16.2% in Q4 2016.

**6. Customers repeat, and the customers who went quiet were not the unprofitable ones.**
Only 12 of 793 customers ordered once. 100 customers placed no order in 2017; they account for 9.1% of lifetime sales (209,028) at a 14.9% margin, slightly above the company's 12.47%.

## What I would look at next

These are questions raised by the data, not conclusions.

- Are the deep discounts in the 11 fully discounted states intentional (clearance, promotions) or a pricing-rule problem? If lines over 20% had not been sold, profit would have been higher, but some of those sales would not have happened at full price.
- Why did the Q4 2017 margin fall? Breaking it down by discount band and region would show whether discounts explain it.
- Is the Tables, Bookcases and Machines pricing sound at moderate discounts, given that deep discounts turn them negative?
- A better definition of a lapsed customer (for example, no order in the last 12 months) would test whether the 100 customers above are really lost.

## Caveats

- The Superstore data is a sample dataset and appears to be synthetic: discounts switch on or off by state in a way real retail data would not. The patterns above describe this dataset and say nothing about a real retailer.
- Everything here is an association. The data cannot separate "the discounts caused the losses" from other differences between states and products, because discount, state and product mix overlap.
- "Lapsed" here only means no order in 2017. The data ends in December 2017, so some of these customers may have ordered later.
- Data cleaning decisions (restored postal-code leading zeros, 32 product IDs with more than one name, one postal code with two city names) are described in the README.
