;; Data Sharing Framework Contract
;; Facilitates deep ocean research collaboration

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_DATASET_NOT_FOUND (err u501))
(define-constant ERR_ACCESS_DENIED (err u502))
(define-constant ERR_INVALID_SHARING_TERMS (err u503))

;; Data Variables
(define-data-var next-dataset-id uint u1)
(define-data-var next-request-id uint u1)

;; Data Maps
(define-map datasets
  { dataset-id: uint }
  {
    title: (string-ascii 100),
    owner: principal,
    mission-id: uint,
    data-type: (string-ascii 50),
    data-hash: (string-ascii 64),
    sharing-level: uint,
    created-date: uint,
    last-updated: uint,
    access-count: uint
  }
)

(define-map dataset-metadata
  { dataset-id: uint }
  {
    description: (string-ascii 300),
    keywords: (string-ascii 200),
    methodology: (string-ascii 200),
    quality-score: uint,
    file-size: uint,
    format: (string-ascii 20)
  }
)

(define-map access-permissions
  { dataset-id: uint, requester: principal }
  {
    permission-level: uint,
    granted-by: principal,
    grant-date: uint,
    expiry-date: uint,
    usage-terms: (string-ascii 200)
  }
)

(define-map access-requests
  { request-id: uint }
  {
    dataset-id: uint,
    requester: principal,
    request-date: uint,
    purpose: (string-ascii 200),
    status: (string-ascii 20),
    reviewed-by: (optional principal)
  }
)

;; Public Functions

;; Register a new dataset
(define-public (register-dataset
  (title (string-ascii 100))
  (mission-id uint)
  (data-type (string-ascii 50))
  (data-hash (string-ascii 64))
  (sharing-level uint))
  (let ((dataset-id (var-get next-dataset-id)))
    (asserts! (> sharing-level u0) ERR_INVALID_SHARING_TERMS)
    (map-set datasets
      { dataset-id: dataset-id }
      {
        title: title,
        owner: tx-sender,
        mission-id: mission-id,
        data-type: data-type,
        data-hash: data-hash,
        sharing-level: sharing-level,
        created-date: block-height,
        last-updated: block-height,
        access-count: u0
      }
    )
    (var-set next-dataset-id (+ dataset-id u1))
    (ok dataset-id)
  )
)

;; Add dataset metadata
(define-public (add-dataset-metadata
  (dataset-id uint)
  (description (string-ascii 300))
  (keywords (string-ascii 200))
  (methodology (string-ascii 200))
  (quality-score uint)
  (file-size uint)
  (format (string-ascii 20)))
  (let ((dataset (unwrap! (map-get? datasets { dataset-id: dataset-id }) ERR_DATASET_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner dataset)) ERR_UNAUTHORIZED)
    (map-set dataset-metadata
      { dataset-id: dataset-id }
      {
        description: description,
        keywords: keywords,
        methodology: methodology,
        quality-score: quality-score,
        file-size: file-size,
        format: format
      }
    )
    (ok true)
  )
)

;; Request access to dataset
(define-public (request-access (dataset-id uint) (purpose (string-ascii 200)))
  (let ((request-id (var-get next-request-id))
        (dataset (unwrap! (map-get? datasets { dataset-id: dataset-id }) ERR_DATASET_NOT_FOUND)))
    (map-set access-requests
      { request-id: request-id }
      {
        dataset-id: dataset-id,
        requester: tx-sender,
        request-date: block-height,
        purpose: purpose,
        status: "pending",
        reviewed-by: none
      }
    )
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Grant access permission
(define-public (grant-access
  (dataset-id uint)
  (requester principal)
  (permission-level uint)
  (expiry-date uint)
  (usage-terms (string-ascii 200)))
  (let ((dataset (unwrap! (map-get? datasets { dataset-id: dataset-id }) ERR_DATASET_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner dataset)) ERR_UNAUTHORIZED)
    (map-set access-permissions
      { dataset-id: dataset-id, requester: requester }
      {
        permission-level: permission-level,
        granted-by: tx-sender,
        grant-date: block-height,
        expiry-date: expiry-date,
        usage-terms: usage-terms
      }
    )
    (ok true)
  )
)

;; Update access request status
(define-public (update-request-status (request-id uint) (new-status (string-ascii 20)))
  (let ((request (unwrap! (map-get? access-requests { request-id: request-id }) ERR_DATASET_NOT_FOUND)))
    (map-set access-requests
      { request-id: request-id }
      (merge request { status: new-status, reviewed-by: (some tx-sender) })
    )
    (ok true)
  )
)

;; Access dataset (increment access count)
(define-public (access-dataset (dataset-id uint))
  (let ((dataset (unwrap! (map-get? datasets { dataset-id: dataset-id }) ERR_DATASET_NOT_FOUND))
        (permission (map-get? access-permissions { dataset-id: dataset-id, requester: tx-sender })))
    (asserts! (or
      (is-eq tx-sender (get owner dataset))
      (is-some permission)
      (>= (get sharing-level dataset) u3)) ERR_ACCESS_DENIED)
    (map-set datasets
      { dataset-id: dataset-id }
      (merge dataset {
        access-count: (+ (get access-count dataset) u1),
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get dataset information
(define-read-only (get-dataset (dataset-id uint))
  (map-get? datasets { dataset-id: dataset-id })
)

;; Get dataset metadata
(define-read-only (get-dataset-metadata (dataset-id uint))
  (map-get? dataset-metadata { dataset-id: dataset-id })
)

;; Get access permission
(define-read-only (get-access-permission (dataset-id uint) (requester principal))
  (map-get? access-permissions { dataset-id: dataset-id, requester: requester })
)

;; Get access request
(define-read-only (get-access-request (request-id uint))
  (map-get? access-requests { request-id: request-id })
)

;; Check if user has access to dataset
(define-read-only (has-dataset-access (dataset-id uint) (user principal))
  (match (map-get? datasets { dataset-id: dataset-id })
    dataset (or
      (is-eq user (get owner dataset))
      (is-some (map-get? access-permissions { dataset-id: dataset-id, requester: user }))
      (>= (get sharing-level dataset) u3))
    false
  )
)
