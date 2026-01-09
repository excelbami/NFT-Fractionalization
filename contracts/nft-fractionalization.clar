(impl-trait .sip-010-trait.sip-010-trait)

(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_NFT_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_FRACTIONALIZED (err u105))
(define-constant ERR_NOT_ALL_FRACTIONS_OWNED (err u106))
(define-constant ERR_TRANSFER_FAILED (err u107))
(define-constant ERR_MINT_FAILED (err u108))
(define-constant ERR_BURN_FAILED (err u109))
(define-constant ERR_BUYOUT_EXISTS (err u110))
(define-constant ERR_NO_BUYOUT (err u111))
(define-constant ERR_BUYOUT_NOT_INITIATOR (err u112))
(define-constant ERR_INSUFFICIENT_FRACTIONS (err u113))

(define-fungible-token fraction-token)

(define-data-var token-name (string-ascii 32) "FracNFT")
(define-data-var token-symbol (string-ascii 10) "FNFT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map fractionalized-nfts
  { nft-contract: principal, nft-id: uint }
  { 
    original-owner: principal,
    total-fractions: uint,
    fractions-outstanding: uint,
    fraction-price: uint,
    is-active: bool
  }
)

(define-map user-balances principal uint)
(define-map user-nft-fractions { user: principal, nft-contract: principal, nft-id: uint } uint)

(define-map buyout-proposals
  { nft-contract: principal, nft-id: uint }
  {
    initiator: principal,
    price-per-fraction: uint,
    fractions-acquired: uint,
    total-cost: uint,
    is-active: bool
  }
)

(define-map dividend-pools
  { nft-contract: principal, nft-id: uint }
  { acc-per-fraction: uint, total-deposited: uint }
)

(define-map user-dividend-acc
  { user: principal, nft-contract: principal, nft-id: uint }
  uint
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? user-balances who)))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply fraction-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-read-only (get-fractionalized-nft (nft-contract principal) (nft-id uint))
  (map-get? fractionalized-nfts { nft-contract: nft-contract, nft-id: nft-id })
)

(define-read-only (get-user-fraction-balance (user principal) (nft-contract principal) (nft-id uint))
  (default-to u0 (map-get? user-nft-fractions { user: user, nft-contract: nft-contract, nft-id: nft-id }))
)

(define-read-only (get-buyout-proposal (nft-contract principal) (nft-id uint))
  (map-get? buyout-proposals { nft-contract: nft-contract, nft-id: nft-id })
)

(define-read-only (get-dividend-pool (nft-contract principal) (nft-id uint))
  (map-get? dividend-pools { nft-contract: nft-contract, nft-id: nft-id })
)

(define-read-only (get-claimable-dividends (user principal) (nft-contract principal) (nft-id uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (pool-opt (map-get? dividend-pools nft-key))
  )
    (if (is-none pool-opt)
      (ok u0)
      (let (
        (pool (unwrap! pool-opt ERR_NFT_NOT_FOUND))
        (user-fractions (get-user-fraction-balance user nft-contract nft-id))
        (last-acc (default-to u0 (map-get? user-dividend-acc { user: user, nft-contract: nft-contract, nft-id: nft-id })))
        (delta (if (> (get acc-per-fraction pool) last-acc) (- (get acc-per-fraction pool) last-acc) u0))
      )
        (ok (* user-fractions delta))
      )
    )
  )
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq from tx-sender) ERR_NOT_TOKEN_OWNER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get-balance-uint from) amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (ft-transfer? fraction-token amount from to))
    (map-set user-balances from (- (get-balance-uint from) amount))
    (map-set user-balances to (+ (get-balance-uint to) amount))
    
    (print { 
      action: "transfer", 
      from: from, 
      to: to, 
      amount: amount,
      memo: memo
    })
    (ok true)
  )
)

(define-public (fractionalize-nft 
  (nft-contract <nft-trait>) 
  (nft-id uint) 
  (total-fractions uint) 
  (fraction-price uint))
  (let (
    (nft-principal (contract-of nft-contract))
    (nft-key { nft-contract: nft-principal, nft-id: nft-id })
  )
    (asserts! (> total-fractions u0) ERR_INVALID_AMOUNT)
    (asserts! (> fraction-price u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? fractionalized-nfts nft-key)) ERR_ALREADY_FRACTIONALIZED)
    
    (try! (contract-call? nft-contract transfer nft-id tx-sender (as-contract tx-sender)))
    
    (map-set fractionalized-nfts nft-key {
      original-owner: tx-sender,
      total-fractions: total-fractions,
      fractions-outstanding: total-fractions,
      fraction-price: fraction-price,
      is-active: true
    })
    
    (try! (ft-mint? fraction-token total-fractions tx-sender))
    (map-set user-balances tx-sender (+ (get-balance-uint tx-sender) total-fractions))
    (map-set user-nft-fractions 
      { user: tx-sender, nft-contract: nft-principal, nft-id: nft-id } 
      total-fractions)
    
    (print { 
      action: "fractionalize", 
      nft-contract: nft-principal, 
      nft-id: nft-id, 
      total-fractions: total-fractions,
      owner: tx-sender
    })
    (ok true)
  )
)

(define-public (update-fraction-price 
  (nft-contract principal) 
  (nft-id uint) 
  (new-price uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (owner (get original-owner nft-data))
  )
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (is-eq owner tx-sender) ERR_OWNER_ONLY)
    (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
    (map-set fractionalized-nfts nft-key (merge nft-data { fraction-price: new-price }))
    (print { 
      action: "update-price", 
      nft-contract: nft-contract, 
      nft-id: nft-id, 
      price: new-price 
    })
    (ok true)
  )
)

(define-public (buy-fractions 
  (nft-contract principal) 
  (nft-id uint) 
  (fraction-amount uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (total-cost (* fraction-amount (get fraction-price nft-data)))
    (current-owner (get original-owner nft-data))
  )
    (asserts! (> fraction-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (>= (get-balance-uint current-owner) fraction-amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? total-cost tx-sender current-owner))
    (try! (ft-transfer? fraction-token fraction-amount current-owner tx-sender))
    
    (map-set user-balances current-owner (- (get-balance-uint current-owner) fraction-amount))
    (map-set user-balances tx-sender (+ (get-balance-uint tx-sender) fraction-amount))
    
    (map-set user-nft-fractions 
      { user: current-owner, nft-contract: nft-contract, nft-id: nft-id }
      (- (get-user-fraction-balance current-owner nft-contract nft-id) fraction-amount))
    
    (map-set user-nft-fractions 
      { user: tx-sender, nft-contract: nft-contract, nft-id: nft-id }
      (+ (get-user-fraction-balance tx-sender nft-contract nft-id) fraction-amount))
    
    (print { 
      action: "buy-fractions", 
      buyer: tx-sender, 
      nft-contract: nft-contract, 
      nft-id: nft-id, 
      amount: fraction-amount,
      cost: total-cost
    })
    (ok true)
  )
)

(define-public (reconstruct-nft (nft-contract <nft-trait>) (nft-id uint))
  (let (
    (nft-principal (contract-of nft-contract))
    (nft-key { nft-contract: nft-principal, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (total-fractions (get total-fractions nft-data))
    (user-fractions (get-user-fraction-balance tx-sender nft-principal nft-id))
  )
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (is-eq user-fractions total-fractions) ERR_NOT_ALL_FRACTIONS_OWNED)
    
    (try! (as-contract (contract-call? nft-contract transfer nft-id tx-sender tx-sender)))
    (try! (ft-burn? fraction-token total-fractions tx-sender))
    
    (map-set user-balances tx-sender (- (get-balance-uint tx-sender) total-fractions))
    (map-delete user-nft-fractions { user: tx-sender, nft-contract: nft-principal, nft-id: nft-id })
    
    (map-set fractionalized-nfts nft-key (merge nft-data { is-active: false }))
    
    (print { 
      action: "reconstruct", 
      owner: tx-sender, 
      nft-contract: nft-principal, 
      nft-id: nft-id 
    })
    (ok true)
  )
)

(define-public (sell-fractions 
  (nft-contract principal) 
  (nft-id uint) 
  (fraction-amount uint) 
  (price-per-fraction uint))
  (let (
    (user-fractions (get-user-fraction-balance tx-sender nft-contract nft-id))
  )
    (asserts! (> fraction-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-fraction u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-fractions fraction-amount) ERR_INSUFFICIENT_BALANCE)
    
    (print { 
      action: "list-fractions", 
      seller: tx-sender, 
      nft-contract: nft-contract, 
      nft-id: nft-id,
      amount: fraction-amount,
      price: price-per-fraction
    })
    (ok true)
  )
)

(define-public (propose-buyout 
  (nft-contract principal) 
  (nft-id uint) 
  (price-per-fraction uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (total-fractions (get total-fractions nft-data))
    (total-buyout-cost (* price-per-fraction total-fractions))
  )
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (> price-per-fraction u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? buyout-proposals nft-key)) ERR_BUYOUT_EXISTS)
    
    (map-set buyout-proposals nft-key {
      initiator: tx-sender,
      price-per-fraction: price-per-fraction,
      fractions-acquired: u0,
      total-cost: u0,
      is-active: true
    })
    
    (print {
      action: "propose-buyout",
      initiator: tx-sender,
      nft-contract: nft-contract,
      nft-id: nft-id,
      price-per-fraction: price-per-fraction,
      total-cost: total-buyout-cost
    })
    (ok true)
  )
)

(define-public (accept-buyout 
  (nft-contract principal) 
  (nft-id uint) 
  (fraction-amount uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (buyout (unwrap! (map-get? buyout-proposals nft-key) ERR_NO_BUYOUT))
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (user-fractions (get-user-fraction-balance tx-sender nft-contract nft-id))
    (payment-amount (* fraction-amount (get price-per-fraction buyout)))
    (initiator (get initiator buyout))
    (new-fractions-acquired (+ (get fractions-acquired buyout) fraction-amount))
    (new-total-cost (+ (get total-cost buyout) payment-amount))
    (total-fractions (get total-fractions nft-data))
  )
    (asserts! (get is-active buyout) ERR_NO_BUYOUT)
    (asserts! (> fraction-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-fractions fraction-amount) ERR_INSUFFICIENT_FRACTIONS)
    
    (try! (stx-transfer? payment-amount initiator tx-sender))
    (try! (ft-transfer? fraction-token fraction-amount tx-sender initiator))
    
    (map-set user-balances tx-sender (- (get-balance-uint tx-sender) fraction-amount))
    (map-set user-balances initiator (+ (get-balance-uint initiator) fraction-amount))
    
    (map-set user-nft-fractions 
      { user: tx-sender, nft-contract: nft-contract, nft-id: nft-id }
      (- user-fractions fraction-amount))
    
    (map-set user-nft-fractions 
      { user: initiator, nft-contract: nft-contract, nft-id: nft-id }
      (+ (get-user-fraction-balance initiator nft-contract nft-id) fraction-amount))
    
    (map-set buyout-proposals nft-key (merge buyout {
      fractions-acquired: new-fractions-acquired,
      total-cost: new-total-cost
    }))
    
    (print {
      action: "accept-buyout",
      seller: tx-sender,
      initiator: initiator,
      nft-contract: nft-contract,
      nft-id: nft-id,
      fraction-amount: fraction-amount,
      payment: payment-amount,
      total-acquired: new-fractions-acquired
    })
    
    (if (is-eq new-fractions-acquired total-fractions)
      (begin
        (map-set buyout-proposals nft-key (merge buyout { is-active: false }))
        (print { action: "buyout-complete", initiator: initiator })
        (ok true)
      )
      (ok true)
    )
  )
)

(define-public (cancel-buyout (nft-contract principal) (nft-id uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (buyout (unwrap! (map-get? buyout-proposals nft-key) ERR_NO_BUYOUT))
  )
    (asserts! (is-eq tx-sender (get initiator buyout)) ERR_BUYOUT_NOT_INITIATOR)
    (asserts! (get is-active buyout) ERR_NO_BUYOUT)
    (asserts! (is-eq (get fractions-acquired buyout) u0) ERR_INSUFFICIENT_BALANCE)
    
    (map-set buyout-proposals nft-key (merge buyout { is-active: false }))
    
    (print {
      action: "cancel-buyout",
      initiator: tx-sender,
      nft-contract: nft-contract,
      nft-id: nft-id
    })
    (ok true)
  )
)

(define-public (deposit-dividends 
  (nft-contract principal) 
  (nft-id uint) 
  (amount uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (total-fractions (get total-fractions nft-data))
    (prev-pool (default-to { acc-per-fraction: u0, total-deposited: u0 } (map-get? dividend-pools nft-key)))
    (acc-increment (if (> total-fractions u0) (/ amount total-fractions) u0))
    (new-acc (+ (get acc-per-fraction prev-pool) acc-increment))
    (new-total (+ (get total-deposited prev-pool) amount))
  )
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set dividend-pools nft-key { acc-per-fraction: new-acc, total-deposited: new-total })
    (print { 
      action: "deposit-dividends", 
      nft-contract: nft-contract, 
      nft-id: nft-id, 
      amount: amount,
      acc: new-acc
    })
    (ok true)
  )
)

(define-public (claim-dividends (nft-contract principal) (nft-id uint))
  (let (
    (recipient tx-sender)
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (pool (unwrap! (map-get? dividend-pools nft-key) ERR_NFT_NOT_FOUND))
    (user-fractions (get-user-fraction-balance recipient nft-contract nft-id))
    (last-acc (default-to u0 (map-get? user-dividend-acc { user: recipient, nft-contract: nft-contract, nft-id: nft-id })))
    (delta (if (> (get acc-per-fraction pool) last-acc) (- (get acc-per-fraction pool) last-acc) u0))
    (payout (* user-fractions delta))
  )
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (> payout u0) ERR_INVALID_AMOUNT)
    (try! (as-contract (stx-transfer? payout tx-sender recipient)))
    (map-set user-dividend-acc { user: recipient, nft-contract: nft-contract, nft-id: nft-id } (get acc-per-fraction pool))
    (print { 
      action: "claim-dividends", 
      nft-contract: nft-contract, 
      nft-id: nft-id, 
      user: recipient, 
      amount: payout 
    })
    (ok true)
  )
)

(define-private (get-balance-uint (who principal))
  (default-to u0 (map-get? user-balances who))
)

(define-read-only (is-dao-or-extension)
  (ok true)
)

(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)
