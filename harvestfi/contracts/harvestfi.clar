;; Parametric Crop Insurance
;; Automatic payouts based on predefined weather triggers without requiring claims

;; Insurance policies
(define-map policies
  { policy-id: uint }
  {
    holder: principal,
    location: (string-ascii 64),             ;; Geographic identifier
    crop-type: (string-ascii 32),            ;; Type of crop insured
    coverage-amount: uint,                   ;; Maximum payout amount
    premium: uint,                           ;; Premium paid
    start-height: uint,                      ;; Block height when coverage begins
    end-height: uint,                        ;; Block height when coverage ends
    active: bool,                            ;; Whether policy is currently active
    drought-threshold: int,                  ;; Rainfall threshold in mm below which payout triggers
    excess-rain-threshold: int,              ;; Rainfall threshold in mm above which payout triggers
    frost-threshold: int,                    ;; Temperature threshold in Celsius below which payout triggers
    payout-executed: bool,                   ;; Whether a payout has been executed
    oracle: principal                        ;; Weather data oracle
  }
)

;; Weather data records
(define-map weather-data
  { location: (string-ascii 64), timestamp: uint }
  {
    rainfall-mm: int,            ;; Rainfall in millimeters
    temperature: int,            ;; Temperature in Celsius
    humidity: uint,              ;; Humidity percentage
    submitter: principal,        ;; Oracle that recorded data
    verified: bool               ;; Whether data is verified by multiple oracles
  }
)

;; Authorized weather oracles
(define-map authorized-oracles
  { submitter: principal }
  {
    name: (string-utf8 128),
    registered-at: uint,
    verified-by: principal,
    active: bool
  }
)

;; Risk pools for each crop type
(define-map risk-pools
  { crop-type: (string-ascii 32) }
  {
    premiums-collected: uint,    ;; Total premiums collected for this crop
    payouts-made: uint,          ;; Total payouts made
    active-policies: uint,       ;; Number of active policies
    reserve-target: uint,        ;; Target reserve ratio (out of 10000)
    balance: uint                ;; Current STX balance in the pool
  }
)

;; Next available policy ID
(define-data-var policy-counter uint u0)

;; Protocol fees
(define-data-var protocol-fee-rate uint u500)  ;; 5% of premiums
(define-data-var fee-recipient principal tx-sender)

;; Register an oracle provider
(define-public (register-data-source (name (string-utf8 128)))
  (begin
    ;; In a real implementation, this would require governance approval
    ;; Simplified for this example
    
    (map-set authorized-oracles
      { submitter: tx-sender }
      {
        name: name,
        registered-at: block-height,
        verified-by: tx-sender,
        active: true
      }
    )
    
    (ok true)
  )
)

;; Check if sender is an authorized oracle
(define-private (is-approved-source (submitter principal))
  (default-to 
    false 
    (get active (map-get? authorized-oracles { submitter: submitter }))
  )
)

;; Create a new insurance policy
(define-public (create-coverage
                (location (string-ascii 64))
                (crop-type (string-ascii 32))
                (coverage-amount uint)
                (premium uint)
                (duration uint)
                (drought-threshold int)
                (excess-rain-threshold int)
                (frost-threshold int)
                (oracle principal))
  (let
    ((policy-id (var-get policy-counter))
     (start-height block-height)
     (end-height (+ block-height duration))
     (protocol-fee (/ (* premium (var-get protocol-fee-rate)) u10000))
     (fund-contribution (- premium protocol-fee)))
    
    ;; Validate parameters
    (asserts! (> coverage-amount u0) (err u"Coverage amount must be positive"))
    (asserts! (> premium u0) (err u"Premium amount must be positive"))
    (asserts! (>= duration u1000) (err u"Coverage duration too short"))
    (asserts! (> drought-threshold (to-int u0)) (err u"Invalid drought threshold"))
    (asserts! (> excess-rain-threshold drought-threshold) (err u"Invalid excess rain threshold"))
    (asserts! (< frost-threshold (to-int u30)) (err u"Invalid frost threshold"))
    (asserts! (is-approved-source oracle) (err u"Oracle provider not authorized"))
    
    ;; Transfer premium payment
    (asserts! (is-ok (stx-transfer? premium tx-sender (as-contract tx-sender))) 
             (err u"Failed to transfer premium payment"))
    
    ;; Transfer protocol fee
    (asserts! (is-ok (as-contract (stx-transfer? protocol-fee tx-sender (var-get fee-recipient))))
             (err u"Failed to transfer protocol fee"))
    
    ;; Create the policy
    (map-set policies
      { policy-id: policy-id }
      {
        holder: tx-sender,
        location: location,
        crop-type: crop-type,
        coverage-amount: coverage-amount,
        premium: premium,
        start-height: start-height,
        end-height: end-height,
        active: true,
        drought-threshold: drought-threshold,
        excess-rain-threshold: excess-rain-threshold,
        frost-threshold: frost-threshold,
        payout-executed: false,
        oracle: oracle
      }
    )
    
    ;; Set next policy ID now to avoid any race conditions
    (var-set policy-counter (+ policy-id u1))
    
    ;; Update risk pool
    (match (map-get? risk-pools { crop-type: crop-type })
      existing-pool (map-set risk-pools
                      { crop-type: crop-type }
                      {
                        premiums-collected: (+ (get premiums-collected existing-pool) fund-contribution),
                        payouts-made: (get payouts-made existing-pool),
                        active-policies: (+ (get active-policies existing-pool) u1),
                        reserve-target: (get reserve-target existing-pool),
                        balance: (+ (get balance existing-pool) fund-contribution)
                      }
                    )
      ;; Create new pool if it doesn't exist
      (map-set risk-pools
        { crop-type: crop-type }
        {
          premiums-collected: fund-contribution,
          payouts-made: u0,
          active-policies: u1,
          reserve-target: u7000,  ;; Default 70% reserve ratio
          balance: fund-contribution
        }
      )
    )
    
    ;; Policy ID counter increment was moved above to avoid race conditions
    
    (ok policy-id)
  )
)

;; Submit weather data (oracle only)
(define-public (submit-climate-data
                (location (string-ascii 64))
                (rainfall-mm int)
                (temperature int)
                (humidity uint))
  (begin
    ;; Validate oracle authorization
    (asserts! (is-approved-source tx-sender) (err u"Not authorized as oracle"))
    
    ;; Record weather data
    (map-set weather-data
      { location: location, timestamp: block-height }
      {
        rainfall-mm: rainfall-mm,
        temperature: temperature,
        humidity: humidity,
        submitter: tx-sender,
        verified: false  ;; Would need verification from multiple oracles in production
      }
    )
    
    ;; Process any policies that might be triggered by this data
    (try! (process-climate-triggers location))
    
    (ok true)
  )
)

;; Process weather triggers for policies
(define-private (process-climate-triggers (location (string-ascii 64)))
  (begin
    ;; In a real implementation, this would iterate through all policies for the location
    ;; and check trigger conditions. Simplified for this example.
    
    ;; Return early if no policies match, to avoid any future issues
    
    ;; For demonstration, we'll process a dummy policy ID 0
    (let ((policy-lookup (map-get? policies { policy-id: u0 })))
      (if (is-some policy-lookup)
        (let ((policy (unwrap-panic policy-lookup)))
          (if (and (is-eq (get location policy) location)
                 (get active policy)
                 (not (get payout-executed policy))
                 (<= (get start-height policy) block-height)
                 (>= (get end-height policy) block-height))
            ;; Policy matches criteria, check triggers
            (let ((evaluation (check-coverage-triggers u0 policy)))
              (if (is-ok evaluation)
                (ok true)
                evaluation))
            ;; Policy doesn't match criteria
            (ok true)))
        ;; No policy found
        (ok true)))
  )
)

;; Check if policy triggers are met
(define-private (check-coverage-triggers (policy-id uint) (policy (tuple 
                                         (holder principal)
                                         (location (string-ascii 64))
                                         (crop-type (string-ascii 32))
                                         (coverage-amount uint)
                                         (premium uint)
                                         (start-height uint)
                                         (end-height uint)
                                         (active bool)
                                         (drought-threshold int)
                                         (excess-rain-threshold int)
                                         (frost-threshold int)
                                         (payout-executed bool)
                                         (oracle principal))))
  (let
    ((weather (unwrap! (map-get? weather-data 
                       { location: (get location policy), timestamp: block-height })
                      (err u"Weather data not found"))))
    
    ;; Check if any trigger conditions are met
    (if (or (< (get rainfall-mm weather) (get drought-threshold policy))
            (> (get rainfall-mm weather) (get excess-rain-threshold policy))
            (< (get temperature weather) (get frost-threshold policy)))
        ;; Trigger conditions met, execute payout
        (execute-coverage-payout policy-id)
        (ok false)
    )
  )
)

;; Execute policy payout
(define-private (execute-coverage-payout (policy-id uint))
  (let
    ((policy-lookup (map-get? policies { policy-id: policy-id })))
    
    ;; Check if policy exists
    (asserts! (is-some policy-lookup) (err u"Policy not found"))
    (let ((policy (unwrap-panic policy-lookup)))
      
      ;; Validate policy is active and payout not already executed
      (asserts! (get active policy) (err u"Policy not active"))
      (asserts! (not (get payout-executed policy)) (err u"Payout already executed"))
      
      ;; Update policy status
      (map-set policies
        { policy-id: policy-id }
        (merge policy { payout-executed: true, active: false })
      )
      
      ;; Update risk pool
      (let ((pool (map-get? risk-pools { crop-type: (get crop-type policy) })))
        (asserts! (is-some pool) (err u"Risk pool not found"))
        
        (let ((pool-data (unwrap-panic pool)))
          (map-set risk-pools
            { crop-type: (get crop-type policy) }
            {
              premiums-collected: (get premiums-collected pool-data),
              payouts-made: (+ (get payouts-made pool-data) (get coverage-amount policy)),
              active-policies: (- (get active-policies pool-data) u1),
              reserve-target: (get reserve-target pool-data),
              balance: (- (get balance pool-data) (get coverage-amount policy))
            }
          )
        )
      )
      
      ;; Transfer payout to policyholder
      (asserts! (is-ok (as-contract (stx-transfer? (get coverage-amount policy) tx-sender (get holder policy))))
                (err u"Failed to transfer payout"))
      
      (ok true)
    )
  )
)

;; Allow a user to cancel policy before end date (partial refund)
(define-public (cancel-coverage (policy-id uint))
  (let
    ((policy-lookup (map-get? policies { policy-id: policy-id })))
    
    ;; Validate policy exists
    (asserts! (is-some policy-lookup) (err u"Policy not found"))
    (let ((policy (unwrap-panic policy-lookup)))
      
      ;; Validate
      (asserts! (is-eq tx-sender (get holder policy)) (err u"Not the policyholder"))
      (asserts! (get active policy) (err u"Policy not active"))
      (asserts! (not (get payout-executed policy)) (err u"Payout already executed"))
      
      ;; Calculate refund based on time remaining
      (let
        ((period-length (- (get end-height policy) (get start-height policy)))
         (time-elapsed (- block-height (get start-height policy)))
         (time-remaining (- period-length time-elapsed))
         (refund-ratio (/ (* time-remaining u10000) period-length))
         (refund (/ (* (get premium policy) refund-ratio) u10000)))
        
        ;; Update policy status
        (map-set policies
          { policy-id: policy-id }
          (merge policy { active: false })
        )
        
        ;; Update risk pool
        (let ((pool (map-get? risk-pools { crop-type: (get crop-type policy) })))
          (asserts! (is-some pool) (err u"Risk pool not found"))
          
          (let ((pool-data (unwrap-panic pool)))
            (map-set risk-pools
              { crop-type: (get crop-type policy) }
              {
                premiums-collected: (get premiums-collected pool-data),
                payouts-made: (get payouts-made pool-data),
                active-policies: (- (get active-policies pool-data) u1),
                reserve-target: (get reserve-target pool-data),
                balance: (- (get balance pool-data) refund)
              }
            )
          )
        )
        
        ;; Transfer refund to policyholder
        (asserts! (is-ok (as-contract (stx-transfer? refund tx-sender (get holder policy))))
                  (err u"Failed to transfer refund"))
        
        (ok refund)
      )
    )
  )
)

;; Verify weather data (multiple oracles required)
(define-public (verify-climate-data
                (location (string-ascii 64))
                (timestamp uint)
                (rainfall-mm int)
                (temperature int)
                (humidity uint))
  (let
    ((weather-record (unwrap! (map-get? weather-data 
                              { location: location, timestamp: timestamp })
                             (err u"Weather data not found"))))
    
    ;; Validate oracle authorization
    (asserts! (is-approved-source tx-sender) (err u"Not authorized as oracle"))
    (asserts! (not (is-eq tx-sender (get submitter weather-record))) 
              (err u"Cannot verify own data"))
    
    ;; Check if data matches within acceptable margin of error
    (asserts! (< (abs (- rainfall-mm (get rainfall-mm weather-record))) (to-int u5)) 
              (err u"Rainfall data differs too much"))
    (asserts! (< (abs (- temperature (get temperature weather-record))) (to-int u2)) 
              (err u"Temperature data differs too much"))
    (asserts! (< (abs-uint humidity (get humidity weather-record)) u5) 
              (err u"Humidity data differs too much"))
    
    ;; Mark data as verified
    (map-set weather-data
      { location: location, timestamp: timestamp }
      (merge weather-record { verified: true })
    )
    
    (ok true)
  )
)

;; Manually trigger policy evaluation (for testing or backup)
(define-public (evaluate-coverage (policy-id uint))
  (let
    ((policy (unwrap! (map-get? policies { policy-id: policy-id }) 
                     (err u"Policy not found")))
     (latest-weather (get-latest-climate (get location policy))))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get holder policy))
                 (is-eq tx-sender (get oracle policy)))
              (err u"Not authorized"))
    (asserts! (get active policy) (err u"Policy not active"))
    (asserts! (not (get payout-executed policy)) (err u"Payout already executed"))
    (asserts! (is-some latest-weather) (err u"No weather data available"))
    
    ;; Check if any trigger conditions are met
    (let ((weather (unwrap-panic latest-weather)))
      (if (or (< (get rainfall-mm weather) (get drought-threshold policy))
              (> (get rainfall-mm weather) (get excess-rain-threshold policy))
              (< (get temperature weather) (get frost-threshold policy)))
          ;; Trigger conditions met, execute payout
          (execute-coverage-payout policy-id)
          (ok false)
      )
    )
  )
)

;; Get latest weather data for a location
(define-private (get-latest-climate (location (string-ascii 64)))
  ;; In a real implementation, this would search for the most recent data
  ;; Simplified for this example
  (map-get? weather-data { location: location, timestamp: block-height })
)

;; Utility function for absolute value (int)
(define-private (abs (x int))
  (if (< x (to-int u0)) (to-int (- u0 (to-uint x))) x)
)

;; Utility function for absolute value (uint)
(define-private (abs-uint (x uint) (y uint))
  (if (> x y) (- x y) (- y x))
)

;; Read-only functions

;; Get policy details
(define-read-only (get-coverage (policy-id uint))
  (ok (unwrap! (map-get? policies { policy-id: policy-id }) (err u"Policy not found")))
)

;; Get weather data
(define-read-only (get-climate-data (location (string-ascii 64)) (timestamp uint))
  (ok (unwrap! (map-get? weather-data { location: location, timestamp: timestamp })
              (err u"Weather data not found")))
)

;; Get risk pool information
(define-read-only (get-insurance-fund (crop-type (string-ascii 32)))
  (ok (unwrap! (map-get? risk-pools { crop-type: crop-type }) (err u"Risk pool not found")))
)

;; Check if oracle is authorized
(define-read-only (check-source-approval (submitter principal))
  (ok (is-approved-source submitter))
)