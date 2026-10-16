# Fable III 120 FPS local comparison

Tested October 15, 2026, using source revision `8fe94f1`, on Daniel's RTX 5090 PC at 1440p, borderless desktop fullscreen. The normal lighting plugin, mesh visibility workaround, and synchronous shaders remained enabled. The launcher preference stayed at 60 FPS; test launches explicitly overrode the cap.

## Procedure and observations

Launched `tools/run.ps1 -FrameLimit 60 -FrameStats`, then the same save with `-FrameLimit 120 -FrameStats`. Daniel walked, turned, and ran in the current gameplay area. A second 120-cap run included at least one minute of movement after loading. Daniel reported normal game speed and animations and smooth controls in both 120-cap checks. No crash occurred during the observed runs.

The final complete 300-submission baseline batch averaged 16.67 ms, with p95 17.06 ms, p99 17.17 ms, maximum 17.43 ms, and no intervals over 50 ms. This is a short reference sample, not an equal-duration controlled route benchmark.

For the longer 120-cap run, the 18 consecutive 300-submission batches ending between local log timestamps 22:28:39.287 and 22:29:31.272 were analyzed after the loading/initial streaming batches:

| Measurement | Result |
| --- | --- |
| Guest submissions sampled | 5,400 |
| Mean interval, derived from rounded batch averages | 10.145 ms |
| Approximate average submission rate | 98.6 per second |
| Batch mean interval range | 8.33–15.64 ms |
| Intervals over 50 ms | 1 of 5,400 |
| Worst interval | 63.07 ms |

Lighter views reached near-120 submission pacing. Heavier views fell below the cap. Earlier loading/streaming batches had substantial spikes and are excluded from this warmed-up sample, not claimed to be eliminated.

## Interpretation and limits

The selected 120 cap is honored, and the tested gameplay did not show a user-observed speed or animation regression. It is not a locked 120 FPS result. These measurements instrument the guest rendering submission routine; they do not independently count displayed unique frames or measure simulation/animation time against a stopwatch.

Source inspection shows the frame cap waits on the rendering thread before the original submission routine. It does not change the runtime's guest clock scalar, initialized to 1.0. This supports the observation but does not prove that every game subsystem is independent of rendering frequency.

Keep 60 FPS as the launcher default. Treat 120 as an optional, locally exercised setting; combat, physics interactions, cutscenes, dialogue synchronization, and later regions still need broader testing. No game-speed patch was justified by this test, and no timing or animation code was changed.

Raw logs remain local (`fable_3_059.log`, `fable_3_060.log`, `fable_3_061.log` in the development runtime's logs directory); game/save data is not included in this report.
