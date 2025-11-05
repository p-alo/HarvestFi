# HarvestFi

## Overview

**HarvestFi** is a decentralized **Parametric Crop Insurance** smart contract built on the Stacks blockchain. It provides **automated weather-index-based payouts** to farmers when predefined environmental thresholds are breached, eliminating the need for manual claims or adjusters. By leveraging **authorized weather data oracles**, HarvestFi ensures fairness, transparency, and instant compensation in response to droughts, floods, or cold stress.

---

## Key Features

### 1. Policy Creation

* Farmers can **purchase coverage** by specifying:

  * Their **region** and **crop type**
  * **Maximum payout** amount
  * **Premium (fee-paid)**
  * **Coverage duration** (in blocks)
  * **Weather thresholds**:

    * `dry-limit` for drought
    * `flood-limit` for excessive rainfall
    * `cold-limit` for frost risk
* A valid oracle must be selected as the **data-source** during policy setup.

### 2. Weather-Indexed Triggers

* Insurance payouts are **automatically executed** when real-time oracle data crosses any of the set thresholds:

  * Rainfall below `dry-limit`
  * Rainfall above `flood-limit`
  * Temperature below `cold-limit`
* No claim filing is required; payouts are triggered directly by **verified climate data submissions**.

### 3. Oracle-Driven Climate Data

* **Approved data providers** (weather oracles) submit regional climate records including:

  * Rainfall (`precipitation-mm`)
  * Temperature (`temp-celsius`)
  * Humidity (`moisture-percent`)
* Multiple oracle confirmations enable **data verification** and **fraud resistance**.

### 4. Automated Fund Management

* Premiums are split into:

  * A **system fee** (default: 5%) for protocol maintenance.
  * A **risk pool contribution** for the specific crop type.
* The system maintains **dedicated risk pools** per crop to manage reserves, payouts, and premium balances efficiently.

### 5. Payout and Refund Logic

* **Payouts** are executed automatically when trigger conditions are met, crediting the policyholder in STX.
* **Policy cancellation** is allowed before coverage expiry, providing a **pro-rata refund** based on remaining duration.
* Risk pools are updated after every payout or refund to maintain accurate fund ratios.

### 6. Decentralized Oracle Verification

* Oracles can **verify** each other’s submitted data within acceptable margins:

  * ±5 mm rainfall difference
  * ±2°C temperature difference
  * ±5% humidity variation
* Verified records are flagged as trustworthy for insurance processing.

---

## Core Data Structures

| Map / Variable       | Description                                                                 |
| -------------------- | --------------------------------------------------------------------------- |
| `coverage-contracts` | Stores all issued insurance policies and their parameters.                  |
| `climate-records`    | Contains recorded weather data per region and timestamp.                    |
| `approved-sources`   | Registry of oracle data providers authorized to record climate information. |
| `insurance-funds`    | Crop-specific risk pools holding collected premiums and paid claim data.    |
| `next-contract-id`   | Tracks the next available insurance policy ID.                              |
| `system-fee-rate`    | Percentage of premiums collected as protocol fees (default: 5%).            |
| `fee-collector`      | Principal address where protocol fees are sent.                             |

---

## Public Functions

| Function                                                                                                                                    | Description                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **`register-data-source(provider-name)`**                                                                                                   | Registers a new weather data oracle.                                               |
| **`create-coverage(region-code, plant-variety, max-payout, fee-paid, protection-period, dry-limit, flood-limit, cold-limit, data-source)`** | Creates a new insurance policy linked to an authorized oracle.                     |
| **`submit-climate-data(region-code, precipitation-mm, temp-celsius, moisture-percent)`**                                                    | Allows an oracle to submit live climate data for a region; triggers payout checks. |
| **`cancel-coverage(contract-id)`**                                                                                                          | Enables policyholders to cancel their coverage early for a proportional refund.    |
| **`verify-climate-data(region-code, recorded-at, precipitation-mm, temp-celsius, moisture-percent)`**                                       | Allows a secondary oracle to verify previously submitted weather data.             |
| **`evaluate-coverage(contract-id)`**                                                                                                        | Manually triggers payout evaluation if automatic processing fails.                 |

---

## Private Functions

| Function                                             | Description                                                                                   |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **`is-approved-source(data-provider)`**              | Checks if a principal is a verified oracle.                                                   |
| **`process-climate-triggers(region-code)`**          | Checks active policies for a region and determines if payout conditions are met.              |
| **`check-coverage-triggers(contract-id, coverage)`** | Compares policy thresholds against the latest weather data.                                   |
| **`execute-coverage-payout(contract-id)`**           | Executes the payout process, transferring funds and updating records.                         |
| **`get-latest-climate(region-code)`**                | Retrieves the most recent weather record for a given region.                                  |
| **`abs(x)` / `abs-uint(x, y)`**                      | Utility functions for computing absolute values for integer and unsigned integer comparisons. |

---

## Read-Only Functions

| Function                                         | Description                                                     |
| ------------------------------------------------ | --------------------------------------------------------------- |
| **`get-coverage(contract-id)`**                  | Returns full details of a given insurance policy.               |
| **`get-climate-data(region-code, recorded-at)`** | Retrieves weather data for a region at a specific block height. |
| **`get-insurance-fund(plant-variety)`**          | Displays risk pool metrics for a specific crop type.            |
| **`check-source-approval(data-provider)`**       | Returns `true` if the specified oracle is authorized.           |

---

## Workflow Example

1. **Oracle Registration**
   A verified meteorological data provider registers using `register-data-source`.

2. **Policy Creation**
   A farmer purchases crop insurance through `create-coverage`, linking it to a chosen oracle.

3. **Data Submission**
   The oracle periodically sends local weather readings via `submit-climate-data`.

4. **Trigger Evaluation**
   If any weather thresholds are breached, the contract automatically executes `execute-coverage-payout`.

5. **Refund Option**
   Before expiration, the farmer can use `cancel-coverage` to get a time-adjusted refund.

6. **Data Verification**
   Other oracles validate submitted climate data through `verify-climate-data` to ensure integrity.

---

## Error Handling and Validation

* All inputs (coverage limits, payouts, durations) are checked for logical consistency.
* Unauthorized oracle submissions or duplicate verifications are rejected.
* System reverts automatically if transfers or data retrieval fail.
* Overlapping or invalid thresholds (e.g., flood limit < dry limit) are blocked at creation.

---

## Security and Reliability

* **Oracle Authorization**: Only approved oracles can record or verify weather data.
* **No Manual Claims**: Payouts occur automatically via smart contract logic.
* **Tamper-Proof Records**: All climate data and payouts are stored immutably on-chain.
* **Proportional Refunds**: Early policy cancellations adjust refund amounts based on elapsed duration.
* **Risk Pool Management**: Ensures crop-specific financial isolation and reserve balancing.

---

## Design Principles

* **Transparency**: Farmers and auditors can verify all data and payouts on-chain.
* **Automation**: Triggers and settlements require no human intervention.
* **Fairness**: Uses verified weather data to eliminate subjectivity in claims.
* **Sustainability**: Maintains crop-based risk pools for balanced fund management.
