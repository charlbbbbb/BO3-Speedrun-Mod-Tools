state("blackops3", "BO3 Steam")
{
    byte20 game_state   : 0xA55BDF4;
    int levelTime       : 0xA5502C0;
    string13 currentMap : 0x940C5E8;
    int split           : 0x17B3C3C8; // 0x17B3C3A8
}

state("boiii", "BOIII Community")
{
    byte20 game_state   : "blackops3.exe", 0xA55BDF4;
    int levelTime       : "blackops3.exe", 0xA5502C0;
    string13 currentMap : "blackops3.exe", 0x940C5E8;
}

startup
{
    vars.split_names = new Dictionary<string, Dictionary<int, string>>()
    {
        {
            "zm_zod", new Dictionary<int, string>()
            {
                {0, "Rift"},
                {1, "Sword"},
                {2, "Flag"},
                {3, "SOE Egg End"}
            }
        },
        {
            "zm_factory", new Dictionary<int, string>()
            {
                {0, "The Giant Egg End"}
            }
        },
        {
            "zm_castle", new Dictionary<int, string>()
            {
                {0, "Bow"},
                {1, "Rocket Test TP"},
                {2, "First TP"},
                {3, "Key Place"},
                {4, "DE Boss Enter"},
                {5, "DE Egg End"}
            }
        },
        {
            "zm_island", new Dictionary<int, string>()
            {
                {0, "Bunker"},
                {1, "Skull"},
                {2, "KT-4"},
                {3, "ZNS Boss Enter"},
                {4, "ZNS Egg End"}
            }
        },
        {
            "zm_stalingrad", new Dictionary<int, string>()
            {
                {0, "Fly 1"},
                {1, "Fly 2"},
                {2, "Challenge Start"},
                {3, "Keycard Lockdown"},
                {4, "Button Press"},
                {5, "GK Egg End"}
            }
        },
        {
            "zm_genesis", new Dictionary<int, string>()
            {
                {0, "Keeper Start"},
                {1, "Squid Leave"},
                {2, "House"},
                {3, "Boss 1"},
                {4, "Basketball"},
                {5, "Boss 2"},
                {6, "Rev Egg End"}
            }
        },
        {
            "zm_tomb", new Dictionary<int, string>()
            {
                {0, "Ice Craft"},
                {1, "Fire Enter"},
                {2, "Lightning Craft"},
                {3, "Ice Leave"},
                {4, "Upgrade"},
                {5, "Fists"},
                {6, "Origins Egg End"}
            }
        },
        {
            "zm_moon", new Dictionary<int, string>()
            {
                {0, "Samantha Says"},
                {1, "Hack Complete"},
                {2, "Ball"},
                {3, "Canister 1"},
                {4, "Canister 2"},
                {5, "Moon Egg End"}
            }
        }
    };

    foreach (var map in vars.split_names.Keys)
    {
        settings.Add(map, true, map);
        var splitDict = vars.split_names[map];
        for (var i = 0; i < splitDict.Count; i++)
        {
            settings.Add(splitDict[i], true, splitDict[i], map);
        }
    }
}

init
{
    string exeName = Path.GetFileName(modules.First().FileName).ToLowerInvariant();

    switch (exeName)
    {
        case "blackops3.exe":
            version = "BO3 Steam";
            break;

        case "boiii.exe":
        case "boiii-develop.exe":
            version = "BOIII Community";
            break;

        default:
            version = "Unknown";
            MessageBox.Show(
                "This game version is currently not supported.\n" +
                "If it is correct, make sure the executable name is supported.",
                "LiveSplit Auto Splitter - Unsupported Game Version");
            break;
    }

    timer.CurrentTimingMethod = TimingMethod.GameTime;
    refreshRate = 50;

    vars.currentStart = 0;
    vars.oldStart = 0;
    vars.fixedOffsetGameTime = 0;

    vars.splitAddress = IntPtr.Zero;
    vars.splitCandidates = new List<IntPtr>();
    vars.lastCandidateA = new Dictionary<IntPtr, int>();
    vars.lastCandidateB = new Dictionary<IntPtr, int>();
    vars.oldSplit = 0;
    vars.currentSplit = 0;
    vars.splitScanCompleted = false;
    vars.splitScanTick = 0;
    vars.splitScanAttempts = 0;

    vars.splitModuleBase = IntPtr.Zero;
    vars.splitCacheChecked = false;
    vars.splitCacheRevision = "";
    vars.splitCachePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
        "LiveSplit_BOIII_EE_Split.txt");

    // check that both split blocks match
    vars.DuplicateBlocksMatch = (Func<byte[], bool>)((region) =>
    {
        if (region == null || region.Length < 64)
        {
            return false;
        }

        for (int i = 0; i < 32; i++)
        {
            if (region[i] != region[i + 32])
            {
                return false;
            }
        }

        return true;
    });

    // check that the block matches a known game state
    vars.IsKnownSplitBlock = (Func<byte[], int, bool>)((region, value) =>
    {
        if (region == null || region.Length < 32)
        {
            return false;
        }

        bool menuLayout = value == 6 &&
            region[0] == 0x06 && region[1] == 0 && region[2] == 0 && region[3] == 0 &&
            region[4] == 0xF7 && region[5] == 0x7F && region[6] == 0 && region[7] == 0 &&
            region[8] == 0x31 && region[9] == 0x03 && region[10] == 0x0C && region[13] == 0 &&
            region[14] == 0 && region[15] == 0 && region[16] == 0 && region[17] == 0 &&
            region[18] == 0 && region[19] == 0 &&
            region[20] == 0xFF && region[21] == 0xFF && region[22] == 0xFF && region[23] == 0x7F &&
            region[24] == 0xEB && region[26] == 0xD4 &&
            region[28] == 0 && region[29] == 0 && region[30] == 0 && region[31] == 0;

        bool zeroLayout = value == 0 &&
            region[5] == 0 && region[6] == 0 && region[7] == 0 &&
            region[24] == 0x1D && region[26] == 0xD2 &&
            region[28] == 0 && region[29] == 0 && region[30] == 0 && region[31] == 0;

        if (zeroLayout)
        {
            for (int i = 8; i < 24; i++)
            {
                if (region[i] != 0)
                {
                    zeroLayout = false;
                    break;
                }
            }
        }

        bool activeLayout = value > 0 &&
            region[6] == 0 && region[7] == 0 &&
            region[8] == 0 && region[9] == 0 && region[10] == 0x4E && region[11] == 0xC1 &&
            region[12] == 0 && region[13] == 0 && region[14] == 0x70 && region[15] == 0x41 &&
            region[16] == 0 && region[17] == 0 && region[18] == 0x70 && region[19] == 0x41 &&
            region[20] == 0 && region[21] == 0 && region[22] == 0x0C && region[23] == 0x42 &&
            region[24] == 0x6A && region[26] == 0x0D &&
            region[28] == 0 && region[29] == 0 && region[30] == 0xA0 && region[31] == 0x41;

        return menuLayout || zeroLayout || activeLayout;
    });

    vars.SaveRevisionCache = (Action<string, long, long, string, string>)(
        (revisionToSave, splitRva, runtimeAddress, transitionDetails, savedAfter) =>
    {
        try
        {
            List<string> retainedLines = new List<string>();
            if (File.Exists((string)vars.splitCachePath))
            {
                bool keepBlock = true;

                foreach (string line in File.ReadAllLines((string)vars.splitCachePath))
                {
                    string blockRevision = "";

                    if (line.StartsWith("BOIII Community r", StringComparison.OrdinalIgnoreCase))
                    {
                        blockRevision = line.Substring("BOIII Community ".Length).Trim();
                    }

                    if (!string.IsNullOrEmpty(blockRevision))
                    {
                        keepBlock = !blockRevision.Equals(revisionToSave, StringComparison.OrdinalIgnoreCase);
                    }

                    if (keepBlock)
                    {
                        retainedLines.Add(line);
                    }
                }
            }

            while (retainedLines.Count > 0 && string.IsNullOrWhiteSpace(retainedLines[0]))
            {
                retainedLines.RemoveAt(0);
            }
            while (retainedLines.Count > 0 && string.IsNullOrWhiteSpace(retainedLines[retainedLines.Count - 1]))
            {
                retainedLines.RemoveAt(retainedLines.Count - 1);
            }

            List<string> outputLines = new List<string>();
            outputLines.Add("BOIII Community " + revisionToSave);
            outputLines.Add("split addresses:");
            outputLines.Add("BlackOps3.exe+" + splitRva.ToString("X"));
            outputLines.Add("BlackOps3.exe+" + (splitRva + 0x20).ToString("X"));
            outputLines.Add("0x" + splitRva.ToString("X"));
            outputLines.Add("0x" + (splitRva + 0x20).ToString("X"));
            outputLines.Add("Selected split pair: 0x" + runtimeAddress.ToString("X") +
                " / 0x" + (runtimeAddress + 0x20).ToString("X") +
                " | " + transitionDetails);
            outputLines.Add("SavedAfter: " + savedAfter);

            if (retainedLines.Count > 0)
            {
                outputLines.Add("");
                outputLines.AddRange(retainedLines);
            }

            File.WriteAllLines((string)vars.splitCachePath, outputLines.ToArray());
            print("saved split address to .txt: " + revisionToSave + " | BlackOps3.exe+0x" +
                splitRva.ToString("X") + " | " + (string)vars.splitCachePath);
        }
        catch (Exception ex)
        {
            print("could not save split address to .txt: " + ex.Message);
        }
    });
}

update
{
    if (version == "BOIII Community" && !(bool)vars.splitScanCompleted)
    {
        string mapNameForSplitScan = (string)current.currentMap;
        bool mapReadyForSplitScan =
            mapNameForSplitScan == "core_frontend" ||
            mapNameForSplitScan == "core_ffotd_tu" ||
            (!string.IsNullOrEmpty(mapNameForSplitScan) &&
                mapNameForSplitScan.StartsWith("zm_", StringComparison.OrdinalIgnoreCase));

        if (!mapReadyForSplitScan)
        {
            vars.splitScanTick = 0;
        }
        else
        {
            vars.splitScanTick = (int)vars.splitScanTick + 1;

            if ((int)vars.splitScanTick >= 50)
            {
                vars.splitScanTick = 0;
                Process scanProcess = (Process)game;
                var splitModule = modules.FirstOrDefault(m =>
                    Path.GetFileName(m.FileName).Equals("blackops3.exe", StringComparison.OrdinalIgnoreCase));

                if (splitModule != null)
                {
                    vars.splitModuleBase = splitModule.BaseAddress;

                    // scan the game data range for split blocks
                    IntPtr dataStart = IntPtr.Add(splitModule.BaseAddress, 0x032D1000);
                    const int dataSize = 0x175D6420;

                    if (!(bool)vars.splitCacheChecked)
                    {
                        string windowTitle = "";
                        try
                        {
                            windowTitle = scanProcess.MainWindowTitle ?? "";
                        }
                        catch (Exception)
                        {
                        }

                        string detectedRevision = "";
                        for (int i = 0; i < windowTitle.Length - 1; i++)
                        {
                            if ((windowTitle[i] == 'r' || windowTitle[i] == 'R') &&
                                char.IsDigit(windowTitle[i + 1]) &&
                                (i == 0 || char.IsWhiteSpace(windowTitle[i - 1])))
                            {
                                int end = i + 1;
                                while (end < windowTitle.Length && char.IsDigit(windowTitle[end]))
                                {
                                    end++;
                                }
                                detectedRevision = windowTitle.Substring(i, end - i);
                                break;
                            }
                        }

                        vars.splitCacheChecked = true;
                        vars.splitCacheRevision = detectedRevision;

                        if (string.IsNullOrEmpty(detectedRevision))
                        {
                            print("client revision not found, scanning without using .txt file");
                        }
                        else
                        {
                            print("client revision: " + detectedRevision);
                        }

                        if (!string.IsNullOrEmpty(detectedRevision))
                        {

                            List<string> cacheBlockLines = new List<string>();
                            bool inMatchingBlock = false;
                            bool foundMatchingBlock = false;

                            if (File.Exists((string)vars.splitCachePath))
                            {
                                foreach (string line in File.ReadAllLines((string)vars.splitCachePath))
                                {
                                    if (line.StartsWith("BOIII Community r", StringComparison.OrdinalIgnoreCase))
                                    {
                                        string headerRevision = line.Substring("BOIII Community ".Length).Trim();

                                        inMatchingBlock = !foundMatchingBlock &&
                                            headerRevision.Equals(detectedRevision, StringComparison.OrdinalIgnoreCase);

                                        if (inMatchingBlock)
                                        {
                                            foundMatchingBlock = true;
                                        }
                                    }
                                    else if (inMatchingBlock)
                                    {
                                        cacheBlockLines.Add(line);
                                    }
                                }
                            }

                            long cachedOffset = -1;
                            long cachedSecondOffset = -1;
                            int offsetsRead = 0;

                            foreach (string cacheLine in cacheBlockLines)
                            {
                                if (!cacheLine.StartsWith("BlackOps3.exe+", StringComparison.OrdinalIgnoreCase))
                                {
                                    continue;
                                }

                                string offsetText = cacheLine.Substring("BlackOps3.exe+".Length).Trim();

                                long parsedOffset;
                                if (long.TryParse(offsetText, System.Globalization.NumberStyles.HexNumber,
                                    System.Globalization.CultureInfo.InvariantCulture, out parsedOffset))
                                {
                                    if (offsetsRead == 0)
                                    {
                                        cachedOffset = parsedOffset;
                                    }
                                    else if (offsetsRead == 1)
                                    {
                                        cachedSecondOffset = parsedOffset;
                                    }

                                    offsetsRead++;
                                }
                            }

                            long dataStartRva = 0x032D1000L;
                            bool cacheOffsetInRange = foundMatchingBlock && cachedOffset >= dataStartRva &&
                                cachedSecondOffset == cachedOffset + 0x20 &&
                                cachedOffset + 64 <= dataStartRva + (long)dataSize;

                            if (cacheOffsetInRange)
                            {
                                IntPtr cachedAddress = IntPtr.Add(splitModule.BaseAddress, (int)cachedOffset);
                                int cachedValueA = scanProcess.ReadValue<int>(cachedAddress);
                                int cachedValueB = scanProcess.ReadValue<int>(IntPtr.Add(cachedAddress, 0x20));
                                byte[] cachedRegion = null;
                                bool cacheValid = false;

                                // check the cached address before using it
                                if (cachedValueA == cachedValueB && cachedValueA >= 0 && cachedValueA <= 7 &&
                                    scanProcess.ReadBytes(cachedAddress, 64, out cachedRegion))
                                {
                                    cacheValid = ((Func<byte[], bool>)vars.DuplicateBlocksMatch)(cachedRegion) &&
                                        ((Func<byte[], int, bool>)vars.IsKnownSplitBlock)(cachedRegion, cachedValueA);
                                }

                                if (cacheValid)
                                {
                                    vars.splitAddress = cachedAddress;
                                    vars.splitScanCompleted = true;

                                    int baseline =
                                        (mapNameForSplitScan == "core_frontend" ||
                                         mapNameForSplitScan == "core_ffotd_tu") ? 0 : cachedValueA;
                                    vars.oldSplit = baseline;
                                    vars.currentSplit = baseline;

                                    print("using saved split address from .txt: BlackOps3.exe+0x" +
                                        cachedOffset.ToString("X") +
                                        " | A=" + cachedValueA + " B=" + cachedValueB);
                                }
                                else
                                {
                                    print("saved split address from .txt failed, scanning memory");
                                }
                            }
                            else if (foundMatchingBlock)
                            {
                                print("saved split address in .txt is invalid, scanning memory");
                            }
                            else
                            {
                                print("no saved split address in .txt for " + detectedRevision +
                                    ", scanning memory");
                            }
                        }
                    }

                    if (!(bool)vars.splitScanCompleted)
                    {
                        vars.splitScanAttempts = (int)vars.splitScanAttempts + 1;
                        var scanner = new SignatureScanner(scanProcess, dataStart, dataSize);

                        // scan for the menu, no-split, and split blocks
                        string inMenu =
                            "06 00 00 00 F7 7F 00 00 31 03 0C ?? ?? 00 00 00 " +
                            "00 00 00 00 FF FF FF 7F EB ?? D4 ?? 00 00 00 00";
                        string noSplitHappened =
                            "00 00 00 00 ?? 00 00 00 00 00 00 00 00 00 00 00 " +
                            "00 00 00 00 00 00 00 00 1D ?? D2 ?? 00 00 00 00";
                        string possibleSplit =
                            "?? ?? ?? ?? ?? ?? 00 00 00 00 4E C1 00 00 70 41 " +
                            "00 00 70 41 00 00 0C 42 6A ?? 0D ?? 00 00 A0 41";

                        var menuMatches = scanner.ScanAll(new SigScanTarget(0,
                            inMenu + " " + inMenu)).ToList();
                        var zeroMatches = scanner.ScanAll(new SigScanTarget(0,
                            noSplitHappened + " " + noSplitHappened)).ToList();
                        var activeMatches = scanner.ScanAll(new SigScanTarget(0,
                            possibleSplit + " " + possibleSplit)).ToList();

                        var rawCandidates = menuMatches.Concat(zeroMatches).Concat(activeMatches).Distinct().ToList();

                        print("scan " + vars.splitScanAttempts + ": revision=" +
                            (string.IsNullOrEmpty((string)vars.splitCacheRevision) ? "unknown" : (string)vars.splitCacheRevision) +
                            " | map=" + mapNameForSplitScan + " | start=0x" + dataStart.ToString("X") +
                            " | size=0x" + dataSize.ToString("X"));
                        print("scan results: menu=" + menuMatches.Count +
                            " no split=" + zeroMatches.Count + " split happened=" + activeMatches.Count +
                            " unique matches=" + rawCandidates.Count);

                        vars.splitCandidates.Clear();
                        vars.lastCandidateA.Clear();
                        vars.lastCandidateB.Clear();

                        int loggedCandidates = 0;

                        foreach (IntPtr candidate in rawCandidates)
                        {
                            if ((candidate.ToInt64() & 0x7) != 0)
                            {
                                continue;
                            }

                            int valueA = scanProcess.ReadValue<int>(candidate);
                            int valueB = scanProcess.ReadValue<int>(IntPtr.Add(candidate, 0x20));
                            if (valueA != valueB || valueA < 0 || valueA > 7)
                            {
                                continue;
                            }

                            byte[] region;
                            if (!scanProcess.ReadBytes(candidate, 64, out region) ||
                                !((Func<byte[], bool>)vars.DuplicateBlocksMatch)(region))
                            {
                                continue;
                            }

                            if (!vars.splitCandidates.Contains(candidate))
                            {
                                vars.splitCandidates.Add(candidate);
                                vars.lastCandidateA[candidate] = valueA;
                                vars.lastCandidateB[candidate] = valueB;

                                if (loggedCandidates < 25)
                                {
                                    print("found split candidate: 0x" + candidate.ToString("X") +
                                        " / 0x" + IntPtr.Add(candidate, 0x20).ToString("X") +
                                        " | A=" + valueA + " B=" + valueB);
                                    loggedCandidates++;
                                }
                            }
                        }

                        print("valid split candidates: " + vars.splitCandidates.Count);

                        if (vars.splitCandidates.Count > 0 ||
                            (int)vars.splitScanAttempts >= 3)
                        {
                            vars.splitScanCompleted = true;

                            if (vars.splitCandidates.Count > 0)
                            {
                                print("split scan complete, tracking candidates");
                            }
                            else
                            {
                                print("no split candidates after 3 scans");
                            }
                        }
                        else
                        {
                            print("no split candidates yet, retrying");
                        }
                    }
                }
            }
        }
    }

    // some maps store the start flag at a different offset
    int offset = 4;
    switch ((string)current.currentMap)
    {
        case "zm_temple":
        case "zm_prototype":
        case "zm_sumpf":
            offset = 0;
            break;
        case "zm_genesis":
            offset = 12;
            break;
        case "zm_zod":
            offset = 16;
            break;
    }

    vars.oldStart = (old.game_state != null && old.game_state.Length >= 20)
        ? BitConverter.ToInt32(old.game_state, offset) : 0;
    vars.currentStart = (current.game_state != null && current.game_state.Length >= 20)
        ? BitConverter.ToInt32(current.game_state, offset) : 0;

    if (vars.oldStart == 0 && vars.currentStart != 0)
    {
        vars.fixedOffsetGameTime = current.levelTime;
    }

    if (version == "BOIII Community")
    {
        Process splitProcess = (Process)game;
        vars.oldSplit = vars.currentSplit;

        if (vars.splitAddress == IntPtr.Zero)
        {
            // find the split block by its value increasing
            foreach (IntPtr candidate in vars.splitCandidates)
            {
                int valueA = splitProcess.ReadValue<int>(candidate);
                int valueB = splitProcess.ReadValue<int>(IntPtr.Add(candidate, 0x20));
                int previousA = vars.lastCandidateA[candidate];
                int previousB = vars.lastCandidateB[candidate];

                if (previousA == previousB && valueA == valueB &&
                    valueA > previousA && valueA > 0 && valueA <= 7 &&
                    current.currentMap != "core_frontend" && current.currentMap != "core_ffotd_tu")
                {
                    byte[] region;
                    if (!splitProcess.ReadBytes(candidate, 64, out region) ||
                        !((Func<byte[], bool>)vars.DuplicateBlocksMatch)(region))
                    {
                        continue;
                    }

                    vars.splitAddress = candidate;
                    vars.oldSplit = previousA;
                    vars.currentSplit = valueA;

                    print("split address found: 0x" + candidate.ToString("X") +
                        " / 0x" + IntPtr.Add(candidate, 0x20).ToString("X") +
                        " | " + previousA + " -> " + valueA);

                    if (!string.IsNullOrEmpty((string)vars.splitCacheRevision) &&
                        (IntPtr)vars.splitModuleBase != IntPtr.Zero)
                    {
                        long splitRva = candidate.ToInt64() - ((IntPtr)vars.splitModuleBase).ToInt64();
                        if (splitRva >= 0)
                        {
                            ((Action<string, long, long, string, string>)vars.SaveRevisionCache)(
                                (string)vars.splitCacheRevision,
                                splitRva,
                                candidate.ToInt64(),
                                "previous=" + previousA + " current=" + valueA,
                                "validated split transition");
                        }
                    }
                    else
                    {
                        print("split found, address not saved to .txt: revision or module base missing");
                    }

                    break;
                }
            }
        }

        if (vars.splitAddress != IntPtr.Zero)
        {
            int liveSplitValue = splitProcess.ReadValue<int>((IntPtr)vars.splitAddress);

            if (current.currentMap == "core_frontend" || current.currentMap == "core_ffotd_tu")
            {
                vars.oldSplit = 0;
                vars.currentSplit = 0;
            }
            else
            {
                vars.currentSplit = liveSplitValue;
            }
        }

        foreach (IntPtr candidate in vars.splitCandidates)
        {
            vars.lastCandidateA[candidate] = splitProcess.ReadValue<int>(candidate);
            vars.lastCandidateB[candidate] = splitProcess.ReadValue<int>(IntPtr.Add(candidate, 0x20));
        }
    }
    else
    {
        vars.oldSplit = old.split;
        vars.currentSplit = current.split;
    }
}

start
{
    return vars.oldStart == 0 && vars.currentStart != 0 && current.currentMap != "core_frontend";
}

split
{
    if (vars.split_names.ContainsKey(current.currentMap))
    {
        var splitMap = vars.split_names[current.currentMap];
        if (splitMap.ContainsKey(vars.oldSplit))
        {
            var splitName = splitMap[vars.oldSplit];
            if (settings[splitName] && vars.currentSplit > vars.oldSplit)
            {
                return true;
            }
        }
    }

    return false;
}

reset
{
    return
        (vars.oldStart != 0 && vars.currentStart == 0) ||
        (old.currentMap != "core_frontend" && current.currentMap == "core_frontend") ||
        (current.levelTime < old.levelTime) ||
        (vars.currentSplit == 0 && vars.oldSplit != 0);
}

onReset
{
    vars.fixedOffsetGameTime = 0;
    vars.oldStart = 0;
    vars.currentStart = 0;
}

isLoading
{
    return true;
}

gameTime
{
    if (current.currentMap == "core_frontend" || vars.currentStart == 0)
    {
        return TimeSpan.Zero;
    }

    int soloMs = (current.levelTime - vars.fixedOffsetGameTime) * 50;
    if (soloMs < 0)
    {
        soloMs = 0;
    }

    return TimeSpan.FromMilliseconds(soloMs);
}
