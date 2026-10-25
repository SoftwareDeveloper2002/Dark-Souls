// A tiny actor made of engine primitives (cube / sphere / cylinder / cone). Characters, projectiles, telegraphs and
// particles are all built from these, so the game runs without any imported art. Swap in real meshes later by
// replacing ADSVisual::AddPart with skeletal / static meshes.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DSVisual.generated.h"

class UStaticMeshComponent;
class UMaterialInstanceDynamic;

UENUM()
enum class EDSShape : uint8 { Cube, Sphere, Cylinder, Cone };

UCLASS()
class DARKSOULS_API ADSVisual : public AActor
{
	GENERATED_BODY()

public:
	ADSVisual();

	/** Adds a primitive. Scale is in metres (1 = 100 cm). Returns the part's index. */
	int32 AddPart(EDSShape Shape, const FVector& LocalMetres, const FVector& ScaleMetres, const FLinearColor& Color);

	UStaticMeshComponent* GetPart(int32 I) const { return Parts.IsValidIndex(I) ? Parts[I] : nullptr; }
	void SetPartColor(int32 I, const FLinearColor& C);
	void SetAllColor(const FLinearColor& C);
	void SetFlash(bool bOn);                       // white-out the whole actor (hit flash)
	void SetShadows(bool bOn);
	void SetCollisionOff();

	/** Sim position (metres, game plane) + height above ground (metres) + facing angle (radians, 0 = +X). */
	void Place(const FVector& WorldCm, float FacingRad);

private:
	UPROPERTY() TObjectPtr<USceneComponent> Pivot;
	UPROPERTY() TArray<TObjectPtr<UStaticMeshComponent>> Parts;
	UPROPERTY() TArray<TObjectPtr<UMaterialInstanceDynamic>> Mats;
	TArray<FLinearColor> BaseColors;
	bool bFlash = false;
	bool bShadows = true;
};
