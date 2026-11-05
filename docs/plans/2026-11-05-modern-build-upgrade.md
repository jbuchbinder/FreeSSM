# FreeSSM — Modern Build & Dependency Upgrade Plan

> **For Hermes:** implement task-by-task with `executing-plans` (single-file build work,
> tasks share `CMakeLists.txt` and `FreeSSM.pro`, so native execution beats per-task subagents).

**Goal:** Move FreeSSM from a Qt4-era qmake project with a 2021-vendored XML parser to a
CMake project on Qt 6.12 LTS, without changing diagnostic behaviour.

**Architecture:** One `CMakeLists.txt` at the repo root builds the single executable
`FreeSSM`, generates/installs the three translations, and installs a flat
"application directory" (the binary, fonts, `background.png`, `definitions/`, `doc/`, `*.qm`)
because every runtime resource is resolved from `QCoreApplication::applicationDirPath()`.
`FreeSSM.pro` stays as a documented fallback for one release, then is deleted.

**Tech stack:** C++17, Qt 6.4+ (built/tested against 6.12.0 LTS), CMake 3.21+, tinyxml2 11.0.0.

**Status of this plan:** analysis is complete and every build claim below was executed on
2026-11-05 against the current `master` (1a0fa09). Task list starts at §5.

---

## 1. Verified starting point (measured, not assumed)

| Build | Qt | Compiler | CMake | Result |
|---|---|---|---|---|
| qmake (`FreeSSM.pro`, unmodified) | 6.8.3 (aqt) | GCC 15.2 | — | 0 errors, 72 warnings (70 are the `QT_DISABLE_DEPRECATED_UP_TO` notice, 2 `QLibraryInfo::location`), binary 2.0 MB, `-h` OK |
| qmake (`FreeSSM.pro`) | 6.12.0 (aqt) | GCC 15.2 | — | 0 errors, 3 warnings, binary OK |
| CMake prototype (Appendix A) | 6.8.3 | GCC 15.2 | 4.2.3 | 0 errors, 0-3 warnings, translations built, install + GUI start OK |
| CMake prototype (Appendix A) | 6.12.0 | GCC 15.2 | 4.2.3 | 0 errors, 3 warnings, `cmake --install` produces the flat app dir, GUI runs offscreen 6 s without error |
| CMake prototype (Appendix A) | 6.4.2 (Ubuntu 24.04 distro) | GCC 13.3 | 3.28.3 | 0 errors, 2 warnings, binary + `-h` OK |
| CMake prototype + tinyxml2 11.0.0 | 6.4.2 / 6.8.3 / 6.12.0 | as above | as above | 0 errors; all 5 shipped `definitions/*.xml` parse with `XML_SUCCESS` |
| CMake prototype `-DFREESSM_USE_SYSTEM_TINYXML2=ON` | 6.4.2 | GCC 13.3 | 3.28.3 | 0 errors against Ubuntu's `libtinyxml2-dev` 10.0.0 |
| **Full Phase 3 dry run** on a throwaway clone (37 guards collapsed, `<QtGui>`→`<QtWidgets>`, `QLibraryInfo::path`, `QFile::open` guarded, `usleep`→`std::this_thread::sleep_for`) | 6.12.0 | GCC 15.2 | 4.2.3 | **0 errors, 0 warnings**, `-h` OK; only residue is one stale comment naming `QRegExp` |

Conclusions that shape this plan:

1. **The sources already compile on Qt 6.12 unchanged.** This is not a rescue port. The
   remaining Qt4 branches are dead code guarded by `#if QT_VERSION < 0x050000`.
2. **The work is dependency currency, build-system modernisation and dead-code removal.**
3. **The `small-resolution` variant is broken today**, under both qmake and CMake: it fails with
   `'preferredSSM2protocol_checkBox' was not declared in this scope` (4 errors) because
   `ui/small/Preferences.ui` lacks widgets the code uses. Pre-existing, not a Qt6 issue.
   Decision A3: leave it in the tree, stop offering it, document it as unsupported.
4. Two build warnings are real API deprecations, not noise: `QLibraryInfo::location` (×2) and
   `QFile::open` ignored result (×1, Qt 6.12 only).

---

## 2. Decisions (from the operator, 2026-11-05)

| ID | Decision | Consequence |
|---|---|---|
| A1 | **Windows is 64-bit only**; document that a 64-bit J2534 DLL is required | Qt 6 ships no x86 Windows binaries (verified in Qt 6.8/6.9/6.10/6.12 "Supported Configurations": only `x86_64` and `ARM64`). The README's 32-bit recommendation dies with this plan. |
| A2 | **Qt floor 6.4, target 6.12 LTS** | Debian 12 / Ubuntu 24.04 (Qt 6.4.2) and Ubuntu 26.04 (6.10.2) users can build from distro packages; CI targets 6.4.2 and 6.12.0. No Qt5 support. |
| A3 | **Leave `small-resolution` broken, documented as unsupported** | Delete the `FREESSM_SMALL_RESOLUTION` CMake option before it is ever added; keep `ui/small/` and `SMALL_RESOLUTION` code untouched; add a README note. |
| A4 | **CMake becomes the build**; keep `FreeSSM.pro` for one release, then delete | `.pro` is trimmed to Qt6-only and made to hard-error on Qt < 6 so the fallback cannot silently produce a Qt5 build. |

---

## 3. Dependency matrix (current → target)

| Component | Current | Target | Why |
|---|---|---|---|
| Build system | qmake (`FreeSSM.pro`, 284 lines, Qt4/5 branches, MinGW DLL copy table) | CMake 3.21+ | Qt's official build system since Qt 6; `qt_add_translations`, deployment helpers, CPack/install and CI integration only exist there. qmake still ships in 6.12 but receives no new features. |
| Qt | "Qt4, Qt5 or Qt6 (experimental)" | 6.4 minimum, 6.12.0 LTS target | Qt 6.12 LTS released 2026-09-30, 5-year support (commercial to 2031-10); 6.8 LTS OSS patches ended 2025-04-02. 6.4 keeps Debian 12 / Ubuntu 24.04 building. |
| C++ standard | `-std=c++11`, promoted to `c++17` only when `QT_VERSION > 5.1` | `CXX_STANDARD 17`, no extensions | Qt 6 requires C++17; the conditional is Qt5 residue. |
| tinyxml2 | vendored 9.0.0 (2021) | vendored 11.0.0 (2025-03-15) | 9.0.0 is affected by CVE-2024-50615 (reachable assertion in `XMLUtil::GetCharacterRef`, CVSS 6.5, fixed in 10.1.0). API-compatible with all call sites in `SSMLegacyDefinitionsInterface.cpp` / `linux/J2534_API.cpp`. Optional `find_package(tinyxml2)` path also verified. |
| Translation tooling | `lrelease FreeSSM.pro` via `QMAKE_EXTRA_TARGETS` | `qt_add_translations(... TS_FILES ...)` | Per-target `.qm` generation, no hand-written install rule. |
| Legacy flags | `-fno-gcse` (GCC ≥ 4.2 workaround), `-lrt` | dropped | `-fno-gcse` is a 2008-era GCC regression workaround; `clock_gettime` lives in libc since glibc 2.17 and `librt` is an empty stub since 2.34. |
| Windows install | copy `Qt5Core.dll`, `libstdc++-6.dll`, `icuin51.dll`, 8.3-name workarounds | `windeployqt` / Qt deploy script | The current table is Qt5/MinGW-specific and wrong for Qt 6. |
| CI | none in repo (there is a stale `origin/ci/windows-build` branch) | GitHub Actions matrix | Nothing verifies a build today. |

Non-goals: no changes to SSM protocol logic, no UI redesign, no macOS support claim, no HiDPI
redesign (but a HiDPI smoke check is in the verification gates), no Qt5 compatibility.

---

## 4. Risks

1. **Windows 64-bit J2534 DLLs (A1).** Users with 32-bit-only clone interfaces lose Windows
   support at Qt 6. Mitigation: README notes it prominently; the Linux build and existing
   Qt5-based releases remain downloadable. This is the plan's largest user-visible cost.
2. **HiDPI.** Qt 6 always scales; the forms use fixed geometry (`setGeometry`, `setFixedSize`,
   4 call sites) and pixel-sized `iconSize` values. A 2× screen may show clipped labels.
   Gate: manual run on a scaled display (Task 17). Fallback: no code change required for
   this plan; file issues if it looks wrong.
3. **Translation drift.** `lupdate` is not run by this plan; the `.ts` files stay as-is, so
   `tr()` strings that changed before this plan are already stale. Out of scope, noted.
4. **qmake fallback drift (A4).** If the `.pro` is kept "just in case", it will silently rot.
   Mitigation: one release, then delete (Task 19); CI builds CMake only.
5. **Qt 6.4 is a floor, not a test target for everything.** It is verified in an Ubuntu 24.04
   container, not on every distro. Debian 12's 6.4.2 should behave identically but is untested.

---

## 5. Tasks

Each task ends with a commit. Commands assume the repo root; `$QT` is a Qt 6.12.0 install
(e.g. the aqt install used for analysis: `~/.hermes/cache/scratch/Qt/6.12.0/gcc_64`).

### Phase 1 — CMake build

#### Task 1: Add `CMakeLists.txt`

**Objective:** A CMake build that produces the same artifact as qmake.

**Files:**
- Create: `CMakeLists.txt` (content: Appendix A, verbatim — it is the verified file)

**Step 1: Write the file**

Copy Appendix A. Do not "improve" it before the first green build; every line was exercised.

**Step 2: Configure and build**

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

Expected: `Configuring done`, `Generating done`, build ends with `Linking CXX executable FreeSSM`,
`0` lines matching `error:`, and exactly `3` lines matching `warning:` (two
`QLibraryInfo::location` deprecations, one `QFile::open` `nodiscard`) on Qt 6.12.
On Qt 6.4.2 expect `2` warnings (the `QFile::open` one is 6.12-only).

**Step 3: Smoke-test the binary**

```bash
QT_QPA_PLATFORM=offscreen ./build/FreeSSM -h | head -3
```

Expected: the usage banner (`Usage:` / `FreeSSM [-c | --controlunit ...]`) and exit code 0.

**Step 4: Commit**

```bash
git add CMakeLists.txt
git commit -m "build: add CMake build for Qt 6"
```

#### Task 2: Keep build output out of the tree

**Objective:** `git status` stays clean after an in-tree build.

**Files:**
- Modify: `.gitignore`

**Step 1:** Append:

```
build*/
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
*.qm
```

(`FreeSSM*` and `Makefile*` already exist and cover the qmake artifacts.)

**Step 2:** Verify

```bash
cmake -S . -B build >/dev/null && git status --porcelain
```

Expected: no output (nothing untracked).

**Step 3:** Commit `git commit -am "build: ignore CMake output"`.

#### Task 3: Prove qmake/CMake parity

**Objective:** Two builds, same observable behaviour.

**Files:** none (verification only).

**Step 1:** Build both into separate dirs:

```bash
cmake -S . -B build-cmake -DCMAKE_BUILD_TYPE=Release && cmake --build build-cmake -j"$(nproc)"
mkdir -p build-qmake && cd build-qmake && qmake6 ../FreeSSM.pro && make release -j"$(nproc)" && cd ..
```

**Step 2:** Compare CLI surface:

```bash
QT_QPA_PLATFORM=offscreen ./build-cmake/FreeSSM -h  > /tmp/cmake-help.txt
QT_QPA_PLATFORM=offscreen ./build-qmake/FreeSSM   -h  > /tmp/qmake-help.txt
diff /tmp/qmake-help.txt /tmp/cmake-help.txt; echo "diff_exit=$?"
```

Expected: `diff_exit=0`, empty diff.

**Step 3:** Compare linkage:

```bash
ldd build-cmake/FreeSSM | grep -c 'libQt6'   # expect 5 (Core, Gui, Widgets, PrintSupport, + transitive)
```

**Step 4:** No commit (verification only). Record the result in the PR description.

#### Task 4: Install layout and installed-app smoke test

**Objective:** `cmake --install` reproduces the flat app directory the code expects.

**Files:** none.

**Step 1:**

```bash
cmake --install build-cmake --prefix /tmp/fs-install
ls /tmp/fs-install
```

Expected, exactly these 11 top-level entries: `FreeSSM`, `FreeSSM_de.qm`, `FreeSSM_en.qm`,
`FreeSSM_tr.qm`, four `LiberationSans-*.ttf`, `background.png`, `definitions/`, `doc/`.

**Step 2:** Run the installed binary:

```bash
QT_QPA_PLATFORM=offscreen timeout 5 /tmp/fs-install/FreeSSM; echo "exit=$?"
```

Expected: `exit=124` (still running when killed) and no output. A `127`/`1` means a missing
resource path and fails the task.

**Step 3:** No commit.

### Phase 2 — Dependency upgrades

#### Task 5: Upgrade tinyxml2 9.0.0 → 11.0.0

**Objective:** Remove the CVE-2024-50615 exposure with a drop-in file swap.

**Files:**
- Replace: `src/tinyxml2/tinyxml2.h`, `src/tinyxml2/tinyxml2.cpp`
- Modify: `src/tinyxml2/readme.md`

**Step 1:** Fetch the release files:

```bash
curl -L -o src/tinyxml2/tinyxml2.h   https://raw.githubusercontent.com/leethomason/tinyxml2/11.0.0/tinyxml2.h
curl -L -o src/tinyxml2/tinyxml2.cpp https://raw.githubusercontent.com/leethomason/tinyxml2/11.0.0/tinyxml2.cpp
grep -E 'TINYXML2_(MAJOR|MINOR|PATCH)_VERSION' src/tinyxml2/tinyxml2.h
```

Expected: `11`, `0`, `0`.

**Step 2:** Update `src/tinyxml2/readme.md` to state the version and upstream tag
(`tinyxml2 11.0.0, https://github.com/leethomason/tinyxml2`, zlib licence).

**Step 3:** Rebuild and verify the parser against the shipped definitions:

```bash
cmake --build build-cmake -j"$(nproc)"
```

Expected: 0 errors. Then save Appendix B as `/tmp/xmlprobe.cpp` and run the probe:

```bash
g++ -std=c++17 -O1 -I src/tinyxml2 -o /tmp/xmlprobe /tmp/xmlprobe.cpp src/tinyxml2/tinyxml2.cpp
/tmp/xmlprobe definitions/*.xml; echo "probe_exit=$?"
```

Expected: five `OK` lines (`J2534libs.xml`, `SSM1defs_ABS.xml`, `SSM1defs_AirConditioning.xml`,
`SSM1defs_CruiseControl.xml`, `SSM1defs_Engine.xml`) and `probe_exit=0`.

**Step 4:** Commit

```bash
git add src/tinyxml2
git commit -m "deps: upgrade tinyxml2 9.0.0 -> 11.0.0 (CVE-2024-50615)"
```

#### Task 6: Verify the system-tinyxml2 option

**Objective:** Packagers can build against a distro `libtinyxml2-dev`.

**Files:** none (already wired in Appendix A as `FREESSM_USE_SYSTEM_TINYXML2`).

**Step 1:**

```bash
cmake -S . -B build-sys -DCMAKE_BUILD_TYPE=Release -DFREESSM_USE_SYSTEM_TINYXML2=ON
cmake --build build-sys -j"$(nproc)"
```

Expected: config log shows `tinyxml2` found; 0 errors. On a distro without the dev package the
configure step must fail with a clear `Could not find a package configuration file provided by
"tinyxml2"` — that is the correct behaviour, not a bug.

**Step 2:** No commit (option shipped in Task 1).

### Phase 3 — Retire Qt4/Qt5 code paths

Mechanical, one commit per task group. **After each task the Qt 6.12 build must stay at
0 errors**, and the warning count must never increase.

#### Task 7: Drop the deprecated-API macro from the qmake project

**Files:** `FreeSSM.pro:175`

**Step 1:** Delete the line
`greaterThan(QT_MAJOR_VERSION, 4): DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x040000` and its
comment. Verified: the build still succeeds without it (Qt 6 default applies).

**Step 2:** Build with qmake to prove the fallback still works:

```bash
cd build-qmake && qmake6 ../FreeSSM.pro && make release -j"$(nproc)" 2>&1 | grep -c 'error:'
```

Expected: `0`, and the `QT_DISABLE_DEPRECATED_UP_TO` `#warning` disappears from the log.

**Step 3:** Commit `git commit -am "build: stop forcing Qt 4.0 deprecation level"`.

#### Task 8: Remove Qt4 QtGui/codec branches

**Files:**
- `src/main.cpp:107-110` — `QTextCodec::setCodecForCStrings` block (`#if QT_VERSION < 0x050000`)
- `src/SSMFlagbyteDefinitionsInterface.cpp` — 4 guard blocks (lines ~156, 252, 331, 437)
- `src/SSMFlagbyteDefinitions_SysDescriptions.cpp:100`
- `src/FreeSSM.cpp:52-56` — `QApplication::desktop()` branch (keep `primaryScreen()`)
- `src/About.cpp:105-112` — guard is `#if QT_VERSION < 0x050E00`; delete the `QDesktopWidget`
  branch, keep the `QScreen` branch
- `src/Preferences.cpp:64-68` — `QRegExp` branch (keep the `QRegularExpression` branch)
- `src/Preferences.cpp:120,138` — guard is `#if QT_VERSION < 0x060000` around
  `activated(QString)`; Qt6-only means the `textActivated(QString)` branch is the survivor
- Header include guards (`#if QT_VERSION < 0x050000 #include <QtGui> #else #include <QtWidgets>`)
  in `src/DiagInterfaceStatusBar.h`, `src/FSSMdialogs.h`, `src/ActuatorTestDlg.h`,
  `src/About.h`, `src/CUcontent_DCs_abstract.h`, `src/CUcontent_MBsSWs.h`

**Step 1:** For every `#if QT_VERSION ...` block keep the Qt6 body and delete the guard lines.
Then rebuild:

```bash
cmake --build build-cmake -j"$(nproc)" 2>&1 | grep -cE 'error:'
```

Expected: `0`.

**Step 2:** Delete the stale commentary that referred to those branches:
- `src/Preferences.cpp` — the line `// NOTE: default pattern syntax QRegExp::RegExp(2) doesn't
  work for "gtk+"/"GTK+" !` is the last mention of `QRegExp` in the tree.
- the six `#include <QtGlobal>\t/* required for QT_VERSION */` lines in `DiagInterfaceStatusBar.h`,
  `CUcontent_DCs_abstract.h`, `FSSMdialogs.h`, `ActuatorTestDlg.h`, `About.h`, `CUcontent_MBsSWs.h`
  — drop the comment (keep the include; it is harmless and QtWidgets pulls it in anyway).

**Step 3:** Confirm no Qt4-only construct remains:

```bash
grep -rn 'QDesktopWidget\|QTextCodec\|QRegExp\|QT_VERSION' src --include='*.cpp' --include='*.h'
```

Expected: no output.

**Step 4:** Commit `git commit -am "src: drop Qt4 code paths"`.

#### Task 9: Collapse the header-resize guards

**Files (6, 37 call sites):** `src/AddMBsSWsDlg.cpp`, `src/CUcontent_Adjustments.cpp`,
`src/CUcontent_DCs_engine.cpp`, `src/CUcontent_DCs_stopCodes.cpp`,
`src/CUcontent_DCs_twoMemories.cpp`, `src/CUcontent_MBsSWs_tableView.cpp`.

**Step 1:** In each `#if QT_VERSION < 0x050000 ... #else ... #endif` keep the
`setSectionResizeMode` calls, drop the `setResizeMode` calls and the guards.

**Step 2:** Verify:

```bash
grep -rc 'setResizeMode' src | grep -v ':0'; echo "---"
cmake --build build-cmake -j"$(nproc)" 2>&1 | grep -cE 'error:'
```

Expected: no `setResizeMode` output, then `0` errors.

**Step 3:** Commit `git commit -am "src: use setSectionResizeMode unconditionally"`.

#### Task 10: Normalise widget includes

**Objective:** `<QtGui>` (Qt4's everything-header) no longer appears.

**Files:** the 21 translation units currently containing `#include <QtGui>` — 20 headers plus
`src/main.cpp:24`.
**Note the ordering trap:** these headers work today only because the generated `ui_*.h`
included *later in the same file* drags in QtWidgets. Replace `<QtGui>` with `<QtWidgets>`;
do not delete the include.

**Step 1:** `grep -rl '#include <QtGui>' src` and replace each occurrence with
`#include <QtWidgets>`.

**Step 2:** Verify:

```bash
grep -rc '#include <QtGui>' src --include='*.h' | grep -v ':0'; echo "---"
cmake --build build-cmake -j"$(nproc)" 2>&1 | grep -cE 'error:'
```

Expected: no output from the grep, then `0` errors.

**Step 3:** Commit `git commit -am "src: include QtWidgets instead of the Qt4 QtGui module"`.

#### Task 11: Fix the three real deprecations

**Files:**
- `src/FreeSSM.cpp:158` and `src/FreeSSM.cpp:479` — `QLibraryInfo::location(QLibraryInfo::TranslationsPath)`
- `src/About.cpp:40-44` — ignored `changelog_file.open(...)` result (Qt 6.12 marks `QFile::open`
  `[[nodiscard]]`)

**Step 1:** Replace both calls with `QLibraryInfo::path(QLibraryInfo::TranslationsPath)`.

**Step 2:** At `src/About.cpp:42` the code is:

```cpp
QFile changelog_file;
changelog_file.setFileName(changelog_filename);
changelog_file.open(QIODevice::ReadOnly | QIODevice::Text);
QString changelog_content = static_cast<QString>(changelog_file.readAll());
```

Guard the read instead of discarding the result:

```cpp
QString changelog_content;
if (changelog_file.open(QIODevice::ReadOnly | QIODevice::Text))
    changelog_content = static_cast<QString>(changelog_file.readAll());
```

**Step 3:** Verify the warning count reaches zero on Qt 6.12:

```bash
cmake --build build-cmake -j"$(nproc)" 2>&1 | grep -cE 'warning:'
```

Expected: `0`.

**Step 4:** Commit `git commit -am "src: replace deprecated QLibraryInfo::location, check QFile::open"`.

#### Task 12: Drop obsolete compiler flags and sleeps

**Files:** `FreeSSM.pro` (flags), `src/linux/serialCOM.cpp:1301` (`usleep`).

**Step 1:** In `FreeSSM.pro` delete `QMAKE_CXXFLAGS += -fno-gcse` (GCC ≥ 4.2 regression
workaround) and `-lrt` from `LIBS` (keep `-ldl`). Verified: both link and run without them on
glibc 2.39+.

**Step 2:** Replace `usleep(1000*duration_ms)` with:

```cpp
std::this_thread::sleep_for(std::chrono::milliseconds(duration_ms));
```

and add `#include <thread>` / `#include <chrono>` to that translation unit. `usleep` is
obsolete POSIX (removed from POSIX.1-2008) and hides behind feature-test macros.

**Step 3:** Build both systems:

```bash
cmake --build build-cmake -j"$(nproc)" 2>&1 | grep -cE 'error:'
cd build-qmake && make release -j"$(nproc)" 2>&1 | grep -cE 'error:'
```

Expected: `0` and `0`.

**Step 4:** Commit `git commit -am "build: drop GCC 4.2 and librt workarounds, replace usleep"`.

#### Task 13: Make the qmake fallback fail loudly on Qt < 6

**Files:** `FreeSSM.pro`

**Step 1:** After the `TEMPLATE` lines add:

```
lessThan(QT_MAJOR_VERSION, 6): error("FreeSSM now requires Qt 6.4 or newer - use CMakeLists.txt or install a Qt 6 development package")
```

and replace the Qt4/Qt5 `dllstarget` body in the `win32` block with a `windeployqt` call:

```
QMAKE_POST_LINK += $$[QT_INSTALL_BINS]/windeployqt --no-translations $$shell_path($$DESTDIR/FreeSSM.exe)
```

**Step 2:** Verify the guard fires:

```bash
grep -n 'requires Qt 6.4' FreeSSM.pro          # expect 1 hit
cd build-qmake && qmake6 ../FreeSSM.pro && echo "qmake_ok"
```

Expected: `qmake_ok` (Qt 6.12 present). A Qt 5 `qmake` must abort with the message above.

**Step 3:** Commit `git commit -am "build: require Qt 6 in the qmake fallback"`.

### Phase 4 — CI, packaging, docs

#### Task 14: CI build matrix

**Objective:** Nothing merges without a green build on the floor and the target.

**Files:**
- Create: `.github/workflows/build.yml` (content: Appendix C)

**Step 1:** Add the workflow with three jobs:
`linux-qt64` (ubuntu-24.04, distro `qt6-base-dev`/`qt6-tools-dev`/`qt6-l10n-tools` → floor
6.4.2), `linux-qt612` (ubuntu-latest + `aqtinstall` 6.12.0 → target), `windows-qt612`
(windows-2022, MSVC, 64-bit).

**Step 2:** Locally reproduce the floor job (the exact container command used for verification):

```bash
docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get -qq update && apt-get -qq install -y qt6-base-dev qt6-tools-dev qt6-l10n-tools cmake g++ make
  cmake -S /src -B /tmp/b -DCMAKE_BUILD_TYPE=Release && cmake --build /tmp/b -j$(nproc)'
```

Expected: 0 errors; 2 warnings.

**Step 3:** Push the branch and confirm all three jobs pass before merging.

**Step 4:** Commit `git commit -am "ci: build Qt 6.4 floor and 6.12 target"`.

#### Task 15: Windows deployment artifact

**Files:** `CMakeLists.txt`

**Step 1:** After `qt_add_executable`, add:

```cmake
if(WIN32)
    qt_generate_deploy_app_script(TARGET FreeSSM OUTPUT_SCRIPT deploy_script NO_UNSUPPORTED_PLATFORM_ERROR)
    install(SCRIPT ${deploy_script})
endif()
```

**Step 2:** Verify in CI only (no Windows host here): the uploaded artifact must contain
`FreeSSM.exe` plus `Qt6Core.dll`, `Qt6Gui.dll`, `Qt6Widgets.dll`, `Qt6PrintSupport.dll` and
`platforms/qwindows.dll`. A `windeployqt` "Unable to find Qt6..." error fails the job.

**Step 3:** Commit `git commit -am "build: deploy Qt runtime on Windows"`.

#### Task 16: CPack installers

**Files:** `CMakeLists.txt`

**Step 1:** Append:

```cmake
set(CPACK_PACKAGE_NAME "FreeSSM")
set(CPACK_PACKAGE_VENDOR "FreeSSM project")
set(CPACK_GENERATOR "TGZ;DEB")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libqt6core6, libqt6gui6, libqt6widgets6, libqt6printsupport6")
set(CPACK_PACKAGE_FILE_NAME "FreeSSM-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
include(CPack)
```

**Step 2:** `cpack -G TGZ --config build-cmake/CPackConfig.cmake` → one `.tar.gz` containing the
flat app directory (`tar tzf` lists `FreeSSM`, `FreeSSM_de.qm`, `definitions/`).

**Step 3:** Commit `git commit -am "build: add CPack packaging"`.

#### Task 17: HiDPI smoke check

**Objective:** Qt 6 scales by default; the forms use fixed pixel geometry.

**Files:** none (verification; file issues if it looks wrong).

**Step 1:** On a 2× display (or `QT_SCALE_FACTOR=2`):

```bash
QT_SCALE_FACTOR=2 ./build-cmake/FreeSSM
```

Open Preferences and one control-unit dialog. Check: labels not clipped, table columns
readable, status bar text complete.

**Step 2:** Record the outcome in the PR. If clipped, open a follow-up issue — do **not** expand
this plan into a layout rewrite.

#### Task 18: Documentation

**Files:** `README.txt` (sections 2, 3, 4, 5), `doc/help_en.html` if it repeats build steps.

**Step 1:** Section 2/3: replace "Qt4, Qt5 or Qt6" with "Qt 6.4 or newer (6.12 LTS recommended)",
list Linux packages (`qt6-base-dev`, `qt6-tools-dev`, `qt6-l10n-tools`, `cmake`, `g++`), drop
the Qt4 archive link, drop the "MinGW version is needed" sentence (MSVC 2022 or MinGW-w64 13+ both
work).

**Step 2:** Add a **Windows 64-bit** paragraph: Qt 6 has no 32-bit Windows binaries; build
64-bit and use a 64-bit J2534 DLL; 32-bit interfaces are no longer supported.

**Step 3:** Replace the compilation section with:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
cmake --install build --prefix "$HOME/FreeSSM"
```

and keep `CONFIG+=small-resolution` out entirely, with one line: "The small-resolution UI variant
is unmaintained and does not build; it is not supported."

**Step 4:** Commit `git commit -am "docs: document the Qt 6 / CMake build"`.

#### Task 19: Delete the qmake project (after the release that ships CMake)

**Files:** delete `FreeSSM.pro`; update README if it still mentions qmake.

**Step 1:** Confirm the release tag built by CI from `CMakeLists.txt` exists, then:

```bash
git rm FreeSSM.pro
grep -rn 'qmake\|\.pro' README.txt   # expect no build instructions
git commit -m "build: remove qmake project (superseded by CMake)"
```

**Step 2:** Post-release only. Do not run this in the same release as Phase 1.

---

## 6. Verification gates

Run before declaring any phase done.

| Gate | Command | Pass condition |
|---|---|---|
| Qt 6.12 build | `cmake --build build-cmake -j` | 0 `error:`, 0 `warning:` |
| Qt 6.4 floor build | the Task 14 container command | 0 `error:` |
| qmake fallback (until Task 19) | `cd build-qmake && make release` | 0 `error:` |
| CLI parity | `diff /tmp/qmake-help.txt /tmp/cmake-help.txt` | identical |
| Install layout | `ls /tmp/fs-install` | 11 entries as listed in Task 4 |
| Installed app starts | `timeout 5 /tmp/fs-install/FreeSSM` | exit 124, no stderr |
| Definition parsing | `/tmp/xmlprobe definitions/*.xml` | 5 × `OK`, exit 0 |
| Qt4 residue | `grep -rn 'QDesktopWidget\|QTextCodec\|QRegExp\|setResizeMode\|QT_VERSION\|#include <QtGui>' src` | no output |
| tinyxml2 version | `grep TINYXML2_MAJOR_VERSION src/tinyxml2/tinyxml2.h` | `11` |

## 7. What this plan deliberately does not do

- Fix `ui/small` (decision A3).
- Run `lupdate` / refresh translations.
- Touch SSM protocol, J2534 or serial logic beyond the `usleep` swap.
- Add unit tests: the codebase has none and the value here is build/deploy correctness, which
  the gates above measure directly. Introducing a test harness is a separate project.

---

## Appendix A — `CMakeLists.txt` (verified, Qt 6.4.2 / 6.8.3 / 6.12.0)

```cmake
cmake_minimum_required(VERSION 3.21)

project(FreeSSM LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

option(FREESSM_USE_SYSTEM_TINYXML2 "Use an installed tinyxml2 instead of the bundled copy" OFF)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Widgets PrintSupport LinguistTools)
qt_standard_project_setup()

# The .ui forms live in ui/. AUTOUIC looks them up by basename from this list.
set(CMAKE_AUTOUIC_SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/ui")

set(FREESSM_SOURCES
    src/main.cpp
    src/FreeSSM.cpp
    src/CmdLine.cpp
    src/EngineDialog.cpp
    src/TransmissionDialog.cpp
    src/ABSdialog.cpp
    src/CruiseControlDialog.cpp
    src/AirConDialog.cpp
    src/Preferences.cpp
    src/About.cpp
    src/FSSMdialogs.cpp
    src/ActuatorTestDlg.cpp
    src/AbstractDiagInterface.cpp
    src/ATcommandControlledDiagInterface.cpp
    src/SerialPassThroughDiagInterface.cpp
    src/J2534DiagInterface.cpp
    src/J2534misc.cpp
    src/SSMP1communication.cpp
    src/SSMP1communication_procedures.cpp
    src/SSMP1base.cpp
    src/SSMP2communication.cpp
    src/SSMP2communication_core.cpp
    src/AbstractSSMcommunication.cpp
    src/SSMprotocol.cpp
    src/SSMprotocol1.cpp
    src/SSMprotocol2.cpp
    src/AddMBsSWsDlg.cpp
    src/ControlUnitDialog.cpp
    src/CUinfo_Engine.cpp
    src/CUinfo_Transmission.cpp
    src/CUinfo_simple.cpp
    src/CUcontent_DCs_abstract.cpp
    src/CUcontent_DCs_engine.cpp
    src/CUcontent_DCs_twoMemories.cpp
    src/CUcontent_DCs_stopCodes.cpp
    src/CUcontent_MBsSWs.cpp
    src/CUcontent_MBsSWs_tableView.cpp
    src/CUcontent_Adjustments.cpp
    src/CUcontent_sysTests.cpp
    src/DiagInterfaceStatusBar.cpp
    src/SSMDefinitionsInterface.cpp
    src/SSMLegacyDefinitionsInterface.cpp
    src/SSMFlagbyteDefinitionsInterface.cpp
    src/SSMFlagbyteDefinitions_SysDescriptions.cpp
    src/SSMFlagbyteDefinitions_en.cpp
    src/SSMFlagbyteDefinitions_de.cpp
    src/SSMFlagbyteDefinitions_tr.cpp
    src/SSMCUdata.cpp
    src/ClearMemoryDlg.cpp
    src/libFSSM.cpp
    src/tinyxml2/tinyxml2.cpp
)

set(FREESSM_HEADERS
    src/FreeSSM.h
    src/Languages.h
    src/CmdLine.h
    src/EngineDialog.h
    src/TransmissionDialog.h
    src/ABSdialog.h
    src/CruiseControlDialog.h
    src/AirConDialog.h
    src/Preferences.h
    src/About.h
    src/FSSMdialogs.h
    src/ActuatorTestDlg.h
    src/AbstractDiagInterface.h
    src/ATcommandControlledDiagInterface.h
    src/SerialPassThroughDiagInterface.h
    src/J2534DiagInterface.h
    src/J2534.h
    src/J2534misc.h
    src/SSMP1communication.h
    src/SSMP1communication_procedures.h
    src/SSMP1base.h
    src/SSMP2communication.h
    src/SSMP2communication_core.h
    src/AbstractSSMcommunication.h
    src/SSMprotocol.h
    src/SSMprotocol1.h
    src/SSMprotocol2.h
    src/AddMBsSWsDlg.h
    src/ControlUnitDialog.h
    src/CUinfo_abstract.h
    src/CUinfo_Engine.h
    src/CUinfo_Transmission.h
    src/CUinfo_simple.h
    src/CUcontent_DCs_abstract.h
    src/CUcontent_DCs_engine.h
    src/CUcontent_DCs_twoMemories.h
    src/CUcontent_DCs_stopCodes.h
    src/CUcontent_MBsSWs.h
    src/CUcontent_MBsSWs_tableView.h
    src/CUcontent_Adjustments.h
    src/CUcontent_sysTests.h
    src/DiagInterfaceStatusBar.h
    src/SSMDefinitionsInterface.h
    src/SSMLegacyDefinitionsInterface.h
    src/SSMFlagbyteDefinitionsInterface.h
    src/SSMFlagbyteDefinitions_SysDescriptions.h
    src/SSMFlagbyteDefinitions_en.h
    src/SSMFlagbyteDefinitions_de.h
    src/SSMFlagbyteDefinitions_tr.h
    src/SSMCUdata.h
    src/ClearMemoryDlg.h
    src/libFSSM.h
    src/tinyxml2/tinyxml2.h
)

set(FREESSM_FORMS
    ui/FreeSSM.ui
    ui/ControlUnitDialog.ui
    ui/CUcontent_DCs_engine.ui
    ui/CUcontent_DCs_twoMemories.ui
    ui/CUcontent_DCs_stopCodes.ui
    ui/CUcontent_MBsSWs.ui
    ui/CUcontent_MBsSWs_tableView.ui
    ui/CUcontent_Adjustments.ui
    ui/CUcontent_sysTests.ui
    ui/AddMBsSWsDlg.ui
    ui/CUinfo_Engine.ui
    ui/CUinfo_Transmission.ui
    ui/CUinfo_simple.ui
    ui/Preferences.ui
    ui/About.ui
    ui/ActuatorTestDlg.ui
)

if(WIN32)
    set(FREESSM_PLATFORM_SOURCES src/windows/serialCOM.cpp src/windows/TimeM.cpp src/windows/J2534_API.cpp)
    set(FREESSM_PLATFORM_HEADERS src/windows/serialCOM.h src/windows/TimeM.h src/windows/J2534_API.h)
    set(FREESSM_PLATFORM_LIBS ws2_32)
else()
    set(FREESSM_PLATFORM_SOURCES src/linux/serialCOM.cpp src/linux/TimeM.cpp src/linux/J2534_API.cpp)
    set(FREESSM_PLATFORM_HEADERS src/linux/serialCOM.h src/linux/TimeM.h src/linux/J2534_API.h)
    set(FREESSM_PLATFORM_LIBS ${CMAKE_DL_LIBS})
endif()

if(FREESSM_USE_SYSTEM_TINYXML2)
    find_package(tinyxml2 10 REQUIRED)
else()
    add_library(tinyxml2 STATIC src/tinyxml2/tinyxml2.cpp src/tinyxml2/tinyxml2.h)
    target_include_directories(tinyxml2 SYSTEM PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
    set_target_properties(tinyxml2 PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()

qt_add_executable(FreeSSM WIN32 MACOSX_BUNDLE
    ${FREESSM_SOURCES} ${FREESSM_HEADERS} ${FREESSM_FORMS}
    ${FREESSM_PLATFORM_SOURCES} ${FREESSM_PLATFORM_HEADERS}
    resources/FreeSSM.qrc
)

target_include_directories(FreeSSM PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/src" "${CMAKE_CURRENT_SOURCE_DIR}/src/tinyxml2")

target_link_libraries(FreeSSM PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::PrintSupport tinyxml2 ${FREESSM_PLATFORM_LIBS})

if(MSVC)
    target_compile_options(FreeSSM PRIVATE /W4)
else()
    target_compile_options(FreeSSM PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()

qt_add_translations(FreeSSM TS_FILES FreeSSM_en.ts FreeSSM_de.ts FreeSSM_tr.ts RESOURCE_PREFIX "/i18n")

# Flat "application directory" install: the app resolves background.png, fonts,
# definitions/, doc/ and the .qm files relative to QCoreApplication::applicationDirPath().
if(NOT DEFINED FREESSM_INSTALL_APPDIR)
    set(FREESSM_INSTALL_APPDIR "." CACHE PATH "Install directory of the FreeSSM application bundle")
endif()

install(TARGETS FreeSSM RUNTIME DESTINATION ${FREESSM_INSTALL_APPDIR} BUNDLE DESTINATION .)
install(FILES background.png LiberationSans-Bold.ttf LiberationSans-BoldItalic.ttf
              LiberationSans-Italic.ttf LiberationSans-Regular.ttf
        DESTINATION ${FREESSM_INSTALL_APPDIR})
install(DIRECTORY definitions/ DESTINATION ${FREESSM_INSTALL_APPDIR}/definitions)
install(DIRECTORY doc/ DESTINATION ${FREESSM_INSTALL_APPDIR}/doc)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/FreeSSM_en.qm ${CMAKE_CURRENT_BINARY_DIR}/FreeSSM_de.qm
              ${CMAKE_CURRENT_BINARY_DIR}/FreeSSM_tr.qm
        DESTINATION ${FREESSM_INSTALL_APPDIR})
```

## Appendix B — XML probe (`/tmp/xmlprobe.cpp`)

```cpp
#include "tinyxml2.h"
#include <cstdio>

int main(int argc, char** argv) {
    int rc = 0;
    for (int i = 1; i < argc; ++i) {
        tinyxml2::XMLDocument doc;
        tinyxml2::XMLError e = doc.LoadFile(argv[i]);
        printf("%-50s %s\n", argv[i], e == tinyxml2::XML_SUCCESS ? "OK" : doc.ErrorStr());
        if (e != tinyxml2::XML_SUCCESS) rc = 1;
    }
    return rc;
}
```

## Appendix C — `.github/workflows/build.yml`

```yaml
name: build
on: [push, pull_request]

jobs:
  linux-floor-qt64:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update
      - run: sudo apt-get install -y qt6-base-dev qt6-tools-dev qt6-l10n-tools cmake g++ make
      - run: cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
      - run: cmake --build build -j"$(nproc)"
      - run: QT_QPA_PLATFORM=offscreen ./build/FreeSSM -h

  linux-target-qt612:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install aqtinstall
      - run: aqt install-qt linux desktop 6.12.0 linux_gcc_64 -O "$HOME/Qt"
      - run: sudo apt-get update && sudo apt-get install -y libgl1-mesa-dev libxkbcommon-dev
      - run: cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$HOME/Qt/6.12.0/gcc_64"
      - run: cmake --build build -j"$(nproc)"
      - run: QT_QPA_PLATFORM=offscreen ./build/FreeSSM -h
      - uses: actions/upload-artifact@v4
        with: { name: FreeSSM-linux-x86_64, path: build/FreeSSM }

  windows-qt612:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v4
      - uses: jurplel/install-qt-action@v4
        with: { version: '6.12.0', arch: 'win64_msvc2022_64' }
      - run: cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
      - run: cmake --build build --config Release -j 4
      - uses: actions/upload-artifact@v4
        with: { name: FreeSSM-windows-x86_64, path: build/Release }
```
