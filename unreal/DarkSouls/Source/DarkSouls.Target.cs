using UnrealBuildTool;
using System.Collections.Generic;

public class DarkSoulsTarget : TargetRules
{
	public DarkSoulsTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V7;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_6;
		CppStandard = CppStandardVersion.Default;
		ShadowVariableWarningLevel = WarningLevel.Off;   // the port reuses short local names (E, Q, S); keep them warnings-free
		ExtraModuleNames.Add("DarkSouls");
	}
}
