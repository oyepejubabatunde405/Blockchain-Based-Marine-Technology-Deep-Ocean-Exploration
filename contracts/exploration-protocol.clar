;; Exploration Protocol Contract
;; Manages deep ocean research missions and protocols

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_MISSION_NOT_FOUND (err u201))
(define-constant ERR_INVALID_DEPTH (err u202))
(define-constant ERR_MISSION_ALREADY_ACTIVE (err u203))

;; Data Variables
(define-data-var next-mission-id uint u1)

;; Data Maps
(define-map missions
  { mission-id: uint }
  {
    title: (string-ascii 100),
    lead-researcher: principal,
    vessel-id: uint,
    target-depth: uint,
    start-date: uint,
    estimated-duration: uint,
    status: (string-ascii 20),
    protocol-approved: bool
  }
)

(define-map mission-protocols
  { mission-id: uint }
  {
    safety-protocol: (string-ascii 200),
    environmental-protocol: (string-ascii 200),
    data-collection-protocol: (string-ascii 200),
    emergency-protocol: (string-ascii 200)
  }
)

(define-map mission-participants
  { mission-id: uint, participant: principal }
  {
    role: (string-ascii 50),
    certification: (string-ascii 50),
    joined-date: uint
  }
)

;; Public Functions

;; Create a new exploration mission
(define-public (create-mission (title (string-ascii 100)) (vessel-id uint) (target-depth uint) (estimated-duration uint))
  (let ((mission-id (var-get next-mission-id)))
    (asserts! (> target-depth u0) ERR_INVALID_DEPTH)
    (map-set missions
      { mission-id: mission-id }
      {
        title: title,
        lead-researcher: tx-sender,
        vessel-id: vessel-id,
        target-depth: target-depth,
        start-date: block-height,
        estimated-duration: estimated-duration,
        status: "planning",
        protocol-approved: false
      }
    )
    (var-set next-mission-id (+ mission-id u1))
    (ok mission-id)
  )
)

;; Set mission protocols
(define-public (set-mission-protocols
  (mission-id uint)
  (safety-protocol (string-ascii 200))
  (environmental-protocol (string-ascii 200))
  (data-collection-protocol (string-ascii 200))
  (emergency-protocol (string-ascii 200)))
  (let ((mission (unwrap! (map-get? missions { mission-id: mission-id }) ERR_MISSION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lead-researcher mission)) ERR_UNAUTHORIZED)
    (map-set mission-protocols
      { mission-id: mission-id }
      {
        safety-protocol: safety-protocol,
        environmental-protocol: environmental-protocol,
        data-collection-protocol: data-collection-protocol,
        emergency-protocol: emergency-protocol
      }
    )
    (ok true)
  )
)

;; Approve mission protocol
(define-public (approve-mission-protocol (mission-id uint))
  (let ((mission (unwrap! (map-get? missions { mission-id: mission-id }) ERR_MISSION_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set missions
      { mission-id: mission-id }
      (merge mission { protocol-approved: true, status: "approved" })
    )
    (ok true)
  )
)

;; Start mission
(define-public (start-mission (mission-id uint))
  (let ((mission (unwrap! (map-get? missions { mission-id: mission-id }) ERR_MISSION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lead-researcher mission)) ERR_UNAUTHORIZED)
    (asserts! (get protocol-approved mission) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq (get status mission) "active")) ERR_MISSION_ALREADY_ACTIVE)
    (map-set missions
      { mission-id: mission-id }
      (merge mission { status: "active", start-date: block-height })
    )
    (ok true)
  )
)

;; Add participant to mission
(define-public (add-participant (mission-id uint) (participant principal) (role (string-ascii 50)) (certification (string-ascii 50)))
  (let ((mission (unwrap! (map-get? missions { mission-id: mission-id }) ERR_MISSION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lead-researcher mission)) ERR_UNAUTHORIZED)
    (map-set mission-participants
      { mission-id: mission-id, participant: participant }
      {
        role: role,
        certification: certification,
        joined-date: block-height
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get mission information
(define-read-only (get-mission (mission-id uint))
  (map-get? missions { mission-id: mission-id })
)

;; Get mission protocols
(define-read-only (get-mission-protocols (mission-id uint))
  (map-get? mission-protocols { mission-id: mission-id })
)

;; Get participant information
(define-read-only (get-participant (mission-id uint) (participant principal))
  (map-get? mission-participants { mission-id: mission-id, participant: participant })
)
