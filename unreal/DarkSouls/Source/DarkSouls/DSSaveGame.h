// Port of save.gd: progress is written after every quest (user://savegame.json in Godot, a USaveGame slot here).
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "DSSaveGame.generated.h"

UCLASS()
class DARKSOULS_API UDSSaveGame : public USaveGame
{
	GENERATED_BODY()

public:
	static const FString SlotName;

	UPROPERTY() int32 Quest = 1;
	UPROPERTY() int32 Souls = 0;
	UPROPERTY() TArray<int32> Lv;              // attack, vigor, endurance, defense, mobility, regen, potency
	UPROPERTY() TArray<int32> SkillUnlocked;   // [weapon * 2 + slot]
	UPROPERTY() TArray<int32> SkillLevel;
	UPROPERTY() int32 Flasks = 3;
	UPROPERTY() int32 Keys = 0;
	UPROPERTY() TArray<int32> WeaponsOwned;    // 0 / 1 per weapon
	UPROPERTY() TArray<int32> WTier;
	UPROPERTY() int32 Equipped = 0;
	UPROPERTY() int32 Ammo = 0;
	UPROPERTY() TArray<int32> ArmorsOwned;
	UPROPERTY() int32 Armor = 0;
	UPROPERTY() bool bUnlimitedAmmo = false;
};
