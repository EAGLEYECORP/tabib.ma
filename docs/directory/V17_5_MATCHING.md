# V17.5 — Doctor ↔ Clinic ↔ Location matching

This layer links public professional doctor records to permitted clinic/location records. It never treats a probabilistic match as verification.

## Confidence
- `>= 0.90`: high-confidence candidate, still requires platform review before `confirmed`.
- `0.75–0.8999`: manual review.
- `< 0.75`: low-confidence candidate.

## Geo
Radius filtering uses an approximation suitable for discovery, not legal address verification. Coordinates must come from an authorized source or a doctor/clinic submission.

## Safety
No private patient data is used. No CNOM login, CAPTCHA bypass, or protected-area extraction is performed.
