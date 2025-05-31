;; Research Vessel Verification Contract
;; Validates deep ocean exploration systems and vessels

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_VESSEL_NOT_FOUND (err u101))
(define-constant ERR_VESSEL_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_CERTIFICATION (err u103))

;; Data Variables
(define-data-var next-vessel-id uint u1)

;; Data Maps
(define-map vessels
  { vessel-id: uint }
  {
    name: (string-ascii 50),
    operator: principal,
    certification-level: uint,
    max-depth: uint,
    equipment-verified: bool,
    registration-date: uint,
    status: (string-ascii 20)
  }
)

(define-map vessel-equipment
  { vessel-id: uint, equipment-type: (string-ascii 30) }
  {
    equipment-name: (string-ascii 50),
    certification-date: uint,
    expiry-date: uint,
    verified: bool
  }
)

;; Public Functions

;; Register a new research vessel
(define-public (register-vessel (name (string-ascii 50)) (max-depth uint) (certification-level uint))
  (let ((vessel-id (var-get next-vessel-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> certification-level u0) ERR_INVALID_CERTIFICATION)
    (map-set vessels
      { vessel-id: vessel-id }
      {
        name: name,
        operator: tx-sender,
        certification-level: certification-level,
        max-depth: max-depth,
        equipment-verified: false,
        registration-date: block-height,
        status: "registered"
      }
    )
    (var-set next-vessel-id (+ vessel-id u1))
    (ok vessel-id)
  )
)

;; Verify vessel equipment
(define-public (verify-equipment (vessel-id uint) (equipment-type (string-ascii 30)) (equipment-name (string-ascii 50)) (expiry-date uint))
  (let ((vessel (unwrap! (map-get? vessels { vessel-id: vessel-id }) ERR_VESSEL_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set vessel-equipment
      { vessel-id: vessel-id, equipment-type: equipment-type }
      {
        equipment-name: equipment-name,
        certification-date: block-height,
        expiry-date: expiry-date,
        verified: true
      }
    )
    (map-set vessels
      { vessel-id: vessel-id }
      (merge vessel { equipment-verified: true, status: "verified" })
    )
    (ok true)
  )
)

;; Update vessel status
(define-public (update-vessel-status (vessel-id uint) (new-status (string-ascii 20)))
  (let ((vessel (unwrap! (map-get? vessels { vessel-id: vessel-id }) ERR_VESSEL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get operator vessel)) ERR_UNAUTHORIZED)
    (map-set vessels
      { vessel-id: vessel-id }
      (merge vessel { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get vessel information
(define-read-only (get-vessel (vessel-id uint))
  (map-get? vessels { vessel-id: vessel-id })
)

;; Get equipment information
(define-read-only (get-equipment (vessel-id uint) (equipment-type (string-ascii 30)))
  (map-get? vessel-equipment { vessel-id: vessel-id, equipment-type: equipment-type })
)

;; Check if vessel is verified
(define-read-only (is-vessel-verified (vessel-id uint))
  (match (map-get? vessels { vessel-id: vessel-id })
    vessel (get equipment-verified vessel)
    false
  )
)
