using UnrealBuildTool;
using System.Collections.Generic;

public class DarkSoulsEditorTarget : TargetRules
{
	public DarkSoulsEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_5;
		ShadowVariableWarningLevel = WarningLevel.Off;   // the port reuses short local names (E, Q, S); keep them warnings-free
		ExtraModuleNames.Add("DarkSouls");
	}
}
