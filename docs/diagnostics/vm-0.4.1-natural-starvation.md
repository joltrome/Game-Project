# VM-0.4.1 natural Refund Coin starvation diagnosis

This file records a factual implementation diagnosis performed before VM-0.4.2.

In a deterministic, real-scheduler 60-second run using seed `401`, VM-0.4.1 accepted and collected only two singleton coins, at 6.500 seconds and 13.600 seconds. The third selected band was retained as `LOW_AIR` from 20.600 seconds through the end of the run. The diagnostic recorded 397 total attempts, 395 rejections, 394 Sweeper-related rejections, no unknown rejection, a cleared active reference after both collection events, and a 0.10-second retry after each failed attempt.

The active-instance cap and retry timer were not stuck. The starvation mechanism was the combination of a permanently retained aerial request and `_sweeper_plan_conflicts`, which rejected that request whenever any active or reserved pattern included a Sweeper. Normal hazard scheduling therefore kept the retained low-air request invalid indefinitely even though forced empty-arena tests could spawn it.

This is an observed implementation result, not a gameplay-quality claim.
