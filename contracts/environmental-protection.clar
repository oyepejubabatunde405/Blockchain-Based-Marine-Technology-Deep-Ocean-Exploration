;; Environmental Protection Contract
;; Ensures deep ocean conservation and compliance

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_VIOLATION_NOT_FOUND (err u401))
(define-constant ERR_INVALID_ZONE (err u402))
(define-constant ERR_ZONE_RESTRICTED (err u403))

;; Data Variables
(define-data-var next-zone-id uint u1)
(define-data-var next-violation-id uint u1)

;; Data Maps
(define-map protected-zones
  { zone-id: uint }
  {
    name: (string-ascii 100),
    min-latitude: int,
    max-latitude: int,
    min-longitude: int,
    max-longitude: int,
    min-depth: uint,
    max-depth: uint,
    protection-level: uint,
    restrictions: (string-ascii 200),
    created-date: uint
  }
)

(define-map zone-permits
  { zone-id: uint, mission-id: uint }
  {
    permit-type: (string-ascii 50),
    granted-by: principal,
    grant-date: uint,
    expiry-date: uint,
    conditions: (string-ascii 200)
  }
)

(define-map environmental-violations
  { violation-id: uint }
  {
    mission-id: uint,
    zone-id: uint,
    violation-type: (string-ascii 50),
    severity: uint,
    reported-by: principal,
    report-date: uint,
    resolved: bool
  }
)

;; Public Functions

;; Create protected zone
(define-public (create-protected-zone
  (name (string-ascii 100))
  (min-latitude int) (max-latitude int)
  (min-longitude int) (max-longitude int)
  (min-depth uint) (max-depth uint)
  (protection-level uint)
  (restrictions (string-ascii 200)))
  (let ((zone-id (var-get next-zone-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (< min-latitude max-latitude) ERR_INVALID_ZONE)
    (asserts! (< min-longitude max-longitude) ERR_INVALID_ZONE)
    (asserts! (< min-depth max-depth) ERR_INVALID_ZONE)
    (map-set protected-zones
      { zone-id: zone-id }
      {
        name: name,
        min-latitude: min-latitude,
        max-latitude: max-latitude,
        min-longitude: min-longitude,
        max-longitude: max-longitude,
        min-depth: min-depth,
        max-depth: max-depth,
        protection-level: protection-level,
        restrictions: restrictions,
        created-date: block-height
      }
    )
    (var-set next-zone-id (+ zone-id u1))
    (ok zone-id)
  )
)

;; Grant zone permit
(define-public (grant-zone-permit
  (zone-id uint)
  (mission-id uint)
  (permit-type (string-ascii 50))
  (expiry-date uint)
  (conditions (string-ascii 200)))
  (let ((zone (unwrap! (map-get? protected-zones { zone-id: zone-id }) ERR_INVALID_ZONE)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set zone-permits
      { zone-id: zone-id, mission-id: mission-id }
      {
        permit-type: permit-type,
        granted-by: tx-sender,
        grant-date: block-height,
        expiry-date: expiry-date,
        conditions: conditions
      }
    )
    (ok true)
  )
)

;; Report environmental violation
(define-public (report-violation (mission-id uint) (zone-id uint) (violation-type (string-ascii 50)) (severity uint))
  (let ((violation-id (var-get next-violation-id)))
    (map-set environmental-violations
      { violation-id: violation-id }
      {
        mission-id: mission-id,
        zone-id: zone-id,
        violation-type: violation-type,
        severity: severity,
        reported-by: tx-sender,
        report-date: block-height,
        resolved: false
      }
    )
    (var-set next-violation-id (+ violation-id u1))
    (ok violation-id)
  )
)

;; Resolve violation
(define-public (resolve-violation (violation-id uint))
  (let ((violation (unwrap! (map-get? environmental-violations { violation-id: violation-id }) ERR_VIOLATION_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set environmental-violations
      { violation-id: violation-id }
      (merge violation { resolved: true })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get protected zone information
(define-read-only (get-protected-zone (zone-id uint))
  (map-get? protected-zones { zone-id: zone-id })
)

;; Get zone permit
(define-read-only (get-zone-permit (zone-id uint) (mission-id uint))
  (map-get? zone-permits { zone-id: zone-id, mission-id: mission-id })
)

;; Get violation information
(define-read-only (get-violation (violation-id uint))
  (map-get? environmental-violations { violation-id: violation-id })
)

;; Check if mission has zone access
(define-read-only (has-zone-access (zone-id uint) (mission-id uint))
  (is-some (map-get? zone-permits { zone-id: zone-id, mission-id: mission-id }))
)

;; Check if coordinates are in protected zone
(define-read-only (is-in-protected-zone (zone-id uint) (latitude int) (longitude int) (depth uint))
  (match (map-get? protected-zones { zone-id: zone-id })
    zone (and
      (>= latitude (get min-latitude zone))
      (<= latitude (get max-latitude zone))
      (>= longitude (get min-longitude zone))
      (<= longitude (get max-longitude zone))
      (>= depth (get min-depth zone))
      (<= depth (get max-depth zone)))
    false
  )
)
