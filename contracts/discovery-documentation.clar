;; Discovery Documentation Contract
;; Records deep ocean discoveries and findings

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_DISCOVERY_NOT_FOUND (err u301))
(define-constant ERR_INVALID_COORDINATES (err u302))

;; Data Variables
(define-data-var next-discovery-id uint u1)

;; Data Maps
(define-map discoveries
  { discovery-id: uint }
  {
    title: (string-ascii 100),
    discoverer: principal,
    mission-id: uint,
    discovery-type: (string-ascii 50),
    depth: uint,
    latitude: int,
    longitude: int,
    discovery-date: uint,
    verified: bool,
    significance-level: uint
  }
)

(define-map discovery-details
  { discovery-id: uint }
  {
    description: (string-ascii 500),
    scientific-classification: (string-ascii 100),
    environmental-impact: (string-ascii 200),
    research-notes: (string-ascii 300),
    data-hash: (string-ascii 64)
  }
)

(define-map discovery-media
  { discovery-id: uint, media-type: (string-ascii 20) }
  {
    media-hash: (string-ascii 64),
    upload-date: uint,
    verified: bool
  }
)

;; Public Functions

;; Record a new discovery
(define-public (record-discovery
  (title (string-ascii 100))
  (mission-id uint)
  (discovery-type (string-ascii 50))
  (depth uint)
  (latitude int)
  (longitude int)
  (significance-level uint))
  (let ((discovery-id (var-get next-discovery-id)))
    (asserts! (> depth u0) ERR_INVALID_COORDINATES)
    (map-set discoveries
      { discovery-id: discovery-id }
      {
        title: title,
        discoverer: tx-sender,
        mission-id: mission-id,
        discovery-type: discovery-type,
        depth: depth,
        latitude: latitude,
        longitude: longitude,
        discovery-date: block-height,
        verified: false,
        significance-level: significance-level
      }
    )
    (var-set next-discovery-id (+ discovery-id u1))
    (ok discovery-id)
  )
)

;; Add detailed information to discovery
(define-public (add-discovery-details
  (discovery-id uint)
  (description (string-ascii 500))
  (scientific-classification (string-ascii 100))
  (environmental-impact (string-ascii 200))
  (research-notes (string-ascii 300))
  (data-hash (string-ascii 64)))
  (let ((discovery (unwrap! (map-get? discoveries { discovery-id: discovery-id }) ERR_DISCOVERY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get discoverer discovery)) ERR_UNAUTHORIZED)
    (map-set discovery-details
      { discovery-id: discovery-id }
      {
        description: description,
        scientific-classification: scientific-classification,
        environmental-impact: environmental-impact,
        research-notes: research-notes,
        data-hash: data-hash
      }
    )
    (ok true)
  )
)

;; Add media to discovery
(define-public (add-discovery-media (discovery-id uint) (media-type (string-ascii 20)) (media-hash (string-ascii 64)))
  (let ((discovery (unwrap! (map-get? discoveries { discovery-id: discovery-id }) ERR_DISCOVERY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get discoverer discovery)) ERR_UNAUTHORIZED)
    (map-set discovery-media
      { discovery-id: discovery-id, media-type: media-type }
      {
        media-hash: media-hash,
        upload-date: block-height,
        verified: false
      }
    )
    (ok true)
  )
)

;; Verify discovery
(define-public (verify-discovery (discovery-id uint))
  (let ((discovery (unwrap! (map-get? discoveries { discovery-id: discovery-id }) ERR_DISCOVERY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set discoveries
      { discovery-id: discovery-id }
      (merge discovery { verified: true })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get discovery information
(define-read-only (get-discovery (discovery-id uint))
  (map-get? discoveries { discovery-id: discovery-id })
)

;; Get discovery details
(define-read-only (get-discovery-details (discovery-id uint))
  (map-get? discovery-details { discovery-id: discovery-id })
)

;; Get discovery media
(define-read-only (get-discovery-media (discovery-id uint) (media-type (string-ascii 20)))
  (map-get? discovery-media { discovery-id: discovery-id, media-type: media-type })
)

;; Check if discovery is verified
(define-read-only (is-discovery-verified (discovery-id uint))
  (match (map-get? discoveries { discovery-id: discovery-id })
    discovery (get verified discovery)
    false
  )
)
