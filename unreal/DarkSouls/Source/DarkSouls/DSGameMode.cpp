#include "DSGameMode.h"
#include "DSGame.h"
#include "DSHUD.h"
#include "DSPlayerController.h"
#include "Engine/World.h"

ADSGameMode::ADSGameMode()
{
	DefaultPawnClass = nullptr;     // the hero is simulated by ADSGame; there is no pawn
	PlayerControllerClass = ADSPlayerController::StaticClass();
	HUDClass = ADSHUD::StaticClass();
}

void ADSGameMode::StartPlay()
{
	Super::StartPlay();
	FActorSpawnParameters Sp;
	Sp.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	Game = GetWorld()->SpawnActor<ADSGame>(FVector::ZeroVector, FRotator::ZeroRotator, Sp);
}
