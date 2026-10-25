#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "DSGameMode.generated.h"

class ADSGame;

/** Sets up the controller + HUD and spawns the game director (ADSGame) when the level starts. */
UCLASS()
class DARKSOULS_API ADSGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ADSGameMode();
	virtual void StartPlay() override;

	UPROPERTY() TObjectPtr<ADSGame> Game;
};
