# AsymmetricFeesHook

## The Problem

Centralized exchanges (CEXs) can move prices within 300ms or even faster, while Ethereum’s average block time is 12 seconds. This discrepancy causes Automated Market Makers (AMMs) to quote stale prices. Informed traders and arbitrageurs exploit these stale quotes, leading to:

- **Direct costs** borne by liquidity providers (LPs).
- **Indirect costs** absorbed by regular traders.

---

## The Solution

Discriminate fees between informed traders and regular traders.  

### Current AMM Behavior

AMMs quote liquidity symmetrically based on their current price. Let’s examine this step by step:

1. **Initial State**:  
   Assume the AMM price matches the CEX price. The AMM quotes a symmetric spread of `2f`, as shown below:

   ![Symmetric Spread](./images/image.png)

2. **Price Movement**:  
   CEX prices move, pushing the price outside the AMM's bid-ask spread.  
   An arbitrageur exploits this by buying ETH from the AMM and selling it on CEXes:  

   ![Arbitrage Flow](./images/image2.png)

3. **After Arbitrage**:  
   - The AMM continues quoting a spread of `2f`.  
   - The **best ask price** aligns with the CEX price, while the **best bid price** is still `2f` away.  
   - This creates an inefficient quote:  
     - The ask side becomes vulnerable to more arbitrage.  
     - The bid side remains too far from the market price.  

   ![Inefficient Spread](./images/image3.png)

---

## Implementing Asymmetric Fees

To address this inefficiency, we introduce **asymmetric fees**:

1. **Adjust Fees**:
   - Move the **best bid and ask prices** to respond to market changes.  
   - Respect the AMM invariant (e.g., `xy = k`) by:
     - Increasing the fee for ETH buys by `δ`.
     - Decreasing the fee for ETH sales by `δ`.  

   ![Asymmetric Fees](./images/image4.png)

2. **Preserve Spread**:  
   - The total quoted spread remains `2f`.  

3. **Formula**:  
   If the AMM price in block `t` changes by `Δ`, then at the top of block `t+1`:
   - **Increase the buy fee**: `fee_buy = fee_buy + δ`  
   - **Decrease the sell fee**: `fee_sell = fee_sell - δ`  
   - Where `δ = cΔ` for some constant `c > 0`.  

   Ensure that neither fee becomes negative.

---

## Why This Works

- **Arbitrage vs. Uninformed Flows**:  
  - Uninformed flows lack significant autocorrelation in direction.  
  - Arbitrage flows, however, exhibit directionality:
    - If the market pushes the AMM's ask, it is more likely to keep pushing the ask than to reverse direction.  
    - Penalizing transactions consistent with the previous block affects arbitrageurs more than uninformed traders.  

---

## Simulation Results

A simulation run by [@0x94305](https://x.com/0x94305) demonstrates the effectiveness of asymmetric fees:

- **Parameters**:
  - Pair: ETH/USDC.
  - Liquidity: $50,000 per basis point.
  - Fee: 5 bps.
  - Daily volatility: 5%.
  - Fees adjusted by 0.75 of the price impact of the previous block.

- **Results**:
  - LP losses reduced by approximately **10%** with dynamic fees compared to fixed fees.
  - Dynamic fees lead to **higher revenues**, eliminating the need for the LVR vs. IL debate.

![Simulation Results](./images/image5.png)
