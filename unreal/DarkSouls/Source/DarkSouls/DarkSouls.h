#pragma once

#include "CoreMinimal.h"
#include "Runtime/Launch/Resources/Version.h"

// The port is configured and verified against Unreal Engine 5.5.x (currently 5.5.4).
// Fail early with a clear message rather than a wall of API errors on a different engine line.
static_assert(ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION == 5,
	"DarkSouls targets Unreal Engine 5.5.x; update Config/Build files before building with another engine line.");
