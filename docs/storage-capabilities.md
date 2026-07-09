# Synology storage manager — capabilities scope

Scope note: the app already shows, read-only, volume space/filesystem/status and disk model/temperature/health from `SYNO.Storage.CGI.Storage` `load_info`. Everything below is what to add on top. All paths/versions resolve through `SYNO.API.Info`; `_sid` attaches post-login; every call here is admin-gated. Where a method or its payload is not confirmed in community code, it is flagged — undocumented APIs, verify at runtime by capturing Storage Manager traffic against the DS920+.

## Additional data we could display (read-only)

- **Storage pool / RAID state.** `SYNO.Storage.CGI.Storage` `load_info` → `storagePools[]`: RAID type (`device_type`), `status` (`normal`/`degraded`/`repairing`/`expanding`/`crashed`), member `disks[]`, SHR sub-pools (`pool_child[]`), rebuild/expand progress. Feasibility: well-attested (hacf-fr sample), same call the app already makes. Value: HIGH — the whole pool/RAID layer is absent today, and "degraded / rebuilding" is the first thing an admin must hear.

- **Full SMART attribute table per disk.** `SYNO.Storage.CGI.Smart` `get_smart_info` (v1): id 5 Reallocated_Sector_Ct, 197 Current_Pending_Sector, 198 Offline_Uncorrectable, 199 UDMA_CRC_Error, 9 Power_On_Hours, 177/231 wear-leveling / SSD_Life_Left, plus NVMe Percentage_Used / Available_Spare. Feasibility: well-attested (confirmed verbatim in N4S4). Value: HIGH — turns a vague "warning" into a specific spoken reason, the core accessibility gap.

- **Overall per-disk health verdict.** `SYNO.Storage.CGI.Smart` `get_health_info` (v1). Feasibility: well-attested. Value: medium-high — one spoken pass/fail per disk.

- **SSD / NVMe remaining-life and threshold flags.** Already in `load_info` disk fields: `remain_life`, `below_remain_life_thr`, `exceed_bad_sector_thr`, `unc_sector`; deeper wear via `get_smart_info`. Feasibility: well-attested. Value: medium-high — proactive endurance warning (DS920+ has M.2 slots).

- **Rebuild / expand / repair progress percentage.** `SYNO.Core.Storage.Pool` `get_progress` and `SYNO.Core.Storage.Volume` `get_progress`; live flag `SYNO.Storage.CGI.Check` `is_building`. Feasibility: well-attested. Value: HIGH — spoken "% complete" during long operations.

- **SMART test progress (live).** In `load_info`: `smart_testing` (bool) + `smart_progress` (% string). Feasibility: well-attested. Value: medium — announce a running test.

- **SMART test history / results.** `SYNO.Storage.CGI.Smart` `list` (v1). Feasibility: well-attested. Value: medium — prior outcomes and dates.

- **Btrfs data-scrub status and schedule.** Volume scrubbing fields in `load_info` + `SYNO.Storage.CGI.Check` `is_data_scrubbing`; schedule via `SYNO.Storage.CGI.Storage` `get_schedule_plan`. Feasibility: well-attested for reads. Value: medium.

- **Volume inode usage.** Inode counters on the `load_info` volume object (cross-check `SYNO.Core.Quota` `inspect`). Feasibility: well-attested. Value: medium — inode exhaustion is an otherwise invisible failure.

- **Live per-disk / per-volume throughput, IOPS, % utilization.** `SYNO.Core.System.Utilization` `get` → `data.disk.disk[]` and `data.space` (`read_byte`/`write_byte`, `read_access`/`write_access` = IOPS, `utilization`). Feasibility: well-attested (N4S4, hacf-fr). Value: medium — needs interval polling; no latency field for disks/volumes.

- **SSD cache inventory and hit rate.** Inventory in `load_info` `ssdCaches[]`; hit rate via `SYNO.Storage.CGI.Flashcache` `statistics`. Feasibility: well-attested. Value: medium, only if a cache exists.

- **Hot-spare list and policy.** `SYNO.Storage.CGI.Spare` `list` and `SYNO.Storage.CGI.Spare.Conf` `get`. Feasibility: `get`/`list` well-attested (`list` works on DSM 7). Value: low-medium.

- **Thresholds, hibernation, firmware-update availability, LED/beep state.** `SYNO.Storage.CGI.HddMan` `get`; `SYNO.Storage.CGI.Smart` `smart_warning_get`; `SYNO.Core.Storage.Disk.FWUpgrade` `get`; `SYNO.Core.Hardware.Led.Brightness` `get`; `SYNO.Core.Hardware.BeepControl` `get`. Feasibility: well-attested. Value: low.

## Operations we could offer

- **Run a SMART test (quick / extended).** `SYNO.Core.Storage.Disk` `do_smart_test`, params: disk `id` + test type (poll `smart_progress` for progress). Legacy fallback: `smart.cgi?action=apply&operation=quick|extended&disk=/dev/sda`. Risk: MODIFYING (non-destructive background activity). Feasibility: `do_smart_test` confirmed in the kwent/N4S4 definition dump; verify exact param shape by capture. (The `SYNO.Storage.CGI.Smart` `run_test` variant is inferred/unconfirmed — prefer `do_smart_test`.)

- **Update local smartctl drive database.** `SYNO.Storage.CGI.Smart` `update_smartctl_db` (v1). Risk: MODIFYING (benign). Feasibility: confirmed.

- **Set SMART warning thresholds.** `SYNO.Storage.CGI.Smart` `smart_warning_set` (v1). Risk: MODIFYING. Feasibility: confirmed method; params capture-verify.

- **Start a data scrub (RAID + Btrfs) or FS-only scrub, with pause/cancel.** `SYNO.Storage.CGI.Volume` `data_scrubbing` / `fs_scrubbing`; `SYNO.Storage.CGI.Pool` `data_scrubbing`; `pause_data_scrubbing`, `cancel_data_scrubbing`; also `SYNO.Storage.CGI.Check` `do_data_scrubbing`. Risk: MODIFYING. Feasibility: method names authoritative; payloads (keyed by volume/pool path or `id`) not wrapped by community libs → capture-verify.

- **Repair a degraded pool / volume (rebuild after disk replacement).** `SYNO.Storage.CGI.Pool` `repair`; `SYNO.Storage.CGI.Volume` `repair`. Risk: MODIFYING. Feasibility: names authoritative; payload capture-verify.

- **Adjust scrub schedule and RAID resync-speed cap.** `SYNO.Storage.CGI.Storage` `set_schedule_plan`, `set_resync_speed`, `set_data_scrubbing_schedule`. Risk: MODIFYING. Feasibility: names authoritative; params capture-verify.

- **Assign / clear a hot spare.** `SYNO.Storage.CGI.Spare` `set`; policy via `SYNO.Storage.CGI.Spare.Conf` `set`. Risk: MODIFYING (claims the spare disk; it is overwritten on rebuild). Feasibility: method confirmed; params capture-verify.

- **Set / enable a volume quota.** `SYNO.Core.Quota` `set`, params: `volume_path`, `enabled`, `quota` (MB). Risk: MODIFYING. Feasibility: param shape confirmed.

- **SSD cache create / remove / repair / configure.** `SYNO.Storage.CGI.Flashcache` `create` (**DESTRUCTIVE** to the chosen SSDs), `remove` (**DESTRUCTIVE** if a read-write cache is dirty/unflushable), `repair` (MODIFYING), `configure` (MODIFYING). Feasibility: method set confirmed; create/remove payloads capture-verify.

- **Create / expand / migrate / delete pool or volume.** `SYNO.Storage.CGI.Pool` and `SYNO.Storage.CGI.Volume`: `create` / `delete` (**DESTRUCTIVE** — wipes disks / drops all data), `expand_by_add_disk`, `migrate` (MODIFYING). Risk: MODIFYING to DESTRUCTIVE. Feasibility: names authoritative, but complex JSON payloads (raid_type + disk-id array + filesystem) are unwrapped → capture-verify; high implementation complexity.

- **Disk firmware upgrade.** `SYNO.Core.Storage.Disk.FWUpgrade` `start`, param `id`. Risk: MODIFYING (risky — flashes drive firmware). Feasibility: confirmed.

- **Deactivate a disk.** `SYNO.Core.Storage.Disk` `test_deactivate_disk` (pre-check, MODIFYING) then `deactivate_disk` (**DESTRUCTIVE to redundancy** — drops the disk, degrades the array); pool-level `SYNO.Storage.CGI.Pool` `deactivate`. Feasibility: `deactivate_disk` confirmed in the definition dump.

- **LED brightness / beep mute.** `SYNO.Core.Hardware.Led.Brightness` `set` (`brightness` int — global chassis, not per-drive locate); `SYNO.Core.Hardware.BeepControl` `set` (method name inferred). Risk: MODIFYING. Feasibility: LED `set` confirmed; beep `set` and any per-disk locate are unconfirmed.

- **Secure erase / erase all data.** `SYNO.Storage.CGI.Smart` `secure_erase` (v1); `SYNO.Storage.CGI.KMIP` `erase_all_data`. Risk: **DESTRUCTIVE** (irreversible). Feasibility: `secure_erase` confirmed. Recommend deferring — no accessibility need, high blast radius.

## Recommended next steps

1. **Add a pool / RAID state panel (read-only).** `load_info` `storagePools[]`. Why: the missing storage layer; degraded/rebuilding is the single most important spoken status, at zero risk from a call the app already issues.

2. **Add rich per-disk SMART/health detail (read-only).** `get_smart_info` + `get_health_info` + `load_info` wear fields. Why: turns a vague "warning" into a specific, spoken reason (pending sectors, wear %) — the core reason this app exists — and is well-attested, read-only.

3. **Announce rebuild / scrub progress (read-only).** `Pool`/`Volume` `get_progress` + `Check.is_building` / `is_data_scrubbing`. Why: long operations need a spoken "% complete"; trivial reads, high reassurance, and it pairs directly with step 1.

4. **Offer "Run SMART test" (modifying, non-destructive).** `SYNO.Core.Storage.Disk` `do_smart_test`, polling `smart_progress`. Why: a safe, self-contained first write action on a confirmed method that lets a user proactively check a suspect drive; verify the param shape by capture first.

5. **Offer "Start data scrub" behind a confirmation (modifying).** `Volume`/`Pool` `data_scrubbing` (+ `cancel`). Why: valuable proactive integrity check; method names are solid but the payload needs capture and it changes system state, so land it after the read-only work and gate it behind an explicit confirm.

## Sources

- https://n4s4.github.io/synology-api/docs/apis
- https://github.com/N4S4/synology-api/blob/master/synology_api/core_storage.py
- https://github.com/N4S4/synology-api/blob/master/synology_api/core_sys_info.py
- https://raw.githubusercontent.com/N4S4/synology-api/master/synology_api/core_service_hw.py
- https://github.com/hacf-fr/synologydsm-api/blob/master/src/synology_dsm/api/storage/storage.py
- https://github.com/hacf-fr/synologydsm-api/blob/master/tests/api_data/dsm_6/storage/const_6_storage_storage.py
- https://github.com/hacf-fr/synologydsm-api/blob/master/src/synology_dsm/api/core/utilization.py
- https://github.com/kwent/syno/blob/master/definitions/6.x/_full.json
- https://github.com/kwent/syno/blob/master/definitions/6.x/SYNO.Storage.CGI.lib
- https://github.com/synology-community/go-synology/blob/main/pkg/api/spec.go
- https://github.com/ClawBow/n8n-nodes-synology-suite/blob/main/ALL_APIS.md
- https://github.com/ClawBow/n8n-nodes-synology-suite/blob/main/PROBE_STORAGE_2026-03-11.md
- https://github.com/007revad/Synology_SMART_info/blob/main/syno_smart_info.sh
- https://github.com/wallacebrf/Synology-SMART-test-scheduler/blob/main/synology_smart/synology_SMART_control.sh
- https://github.com/wallacebrf/Synology_Data_Scrub_Status
- https://github.com/gethomepage/homepage/discussions/4879
- https://gist.github.com/ivaniskandar/5c9d00d7577b49c43ce960a18971ab81
- https://ssd-disclosure.com/ssd-advisory-synology-storagemanager-smart-cgi-remote-command-execution/
- https://kb.synology.com/en-global/PAS/help/PAS/StorageManager/drive_smart_test
- https://kb.synology.com/en-af/PAS/help/PAS/StorageManager/drive_activate
- https://kb.synology.com/en-global/DSM/help/DSM/StorageManager/disk
- https://kb.synology.com/en-us/DSM/help/DSM/StorageManager/storage_pool_data_scrubbing?version=7
- https://kb.synology.com/en-us/DSM/help/DSM/StorageManager/storage_pool_repair?version=7
- https://kb.synology.com/en-global/DSM/help/DSM/StorageManager/ssd_cache_create?version=7
- https://kb.synology.com/en-global/DSM/help/DSM/StorageManager/ssd_cache_manage?version=7
- https://kb.synology.com/en-nz/DSM/help/DSM/StorageManager/hotspare?version=7
- https://kb.synology.com/en-us/DSM/help/DSM/ResourceMonitor/rsrcmonitor_performance
- https://blog.synology.com/how-data-scrubbing-protects-against-data-corruption/
- https://mariushosting.com/synology-cache-hit-rate-in-dsm-7/
- https://global.download.synology.com/download/Document/Software/WhitePaper/Os/DSM/All/enu/Synology_SSD_Cache_White_Paper_enu.pdf