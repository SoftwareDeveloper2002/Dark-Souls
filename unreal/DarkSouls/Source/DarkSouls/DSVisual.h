// A tiny actor made of engine primitives (cube / sphere / cylinder / cone). Characters, projectiles, telegraphs and
// particles are all built from these, so the game runs without any imported art. Swap in real meshes later by
// replacing ADSVisual::AddPart with skeletal / static meshes.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/PointLight.h"
#include "Components/PointLightComponent.h"
#include "DSVisual.generated.h"

class UStaticMeshComponent;
class UMaterialInstanceDynamic;
class UInstancedStaticMeshComponent;

/** Sets a point light's reach (cm) without depending on how APointLight exposes its component. */
inline void DSSetLightRadius(APointLight* L, float Radius)
{
	if (L)
		if (UPointLightComponent* C = Cast<UPointLightComponent>(L->GetLightComponent())) C->SetAttenuationRadius(Radius);
}

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

	/** One draw call for many copies of a primitive (walls, trees). Add copies with AddInstance. */
	UInstancedStaticMeshComponent* AddInstanced(EDSShape Shape, const FLinearColor& Color);
	/** Same, but with an imported static mesh (null when it has not been imported). OutHeightM = the mesh's height in metres, OutBaseM = how far its lowest point is below its origin. */
	UInstancedStaticMeshComponent* AddInstancedModel(const FString& Folder, const FString& Key, float& OutHeightM, float& OutBaseM);
	static void AddInstance(UInstancedStaticMeshComponent* C, const FVector& WorldCm, const FVector& ScaleMetres, float YawRad);

	UStaticMeshComponent* GetPart(int32 I) const { return Parts.IsValidIndex(I) ? Parts[I] : nullptr; }
	void SetPartColor(int32 I, const FLinearColor& C);
	void SetAllColor(const FLinearColor& C);
	void SetFlash(bool bOn);                       // white-out the whole actor (hit flash)
	void SetShadows(bool bOn);
	void SetCollisionOff();

	/**
	 * Dresses the figure in an imported model (see unreal/tools/import_assets.py). Looks under /Game/Models/<Folder> for the asset named Key
	 * (static or skeletal mesh), scales it to HeightMetres and hides the primitive parts listed in HidePrimitives.
	 * Returns false (and changes nothing) when the model has not been imported, so the game still works from primitives.
	 */
	bool AttachModel(const FString& Folder, const FString& Key, float HeightMetres, const TArray<int32>& HidePrimitives, float YawOffsetDeg = 0.f);

	/**
	 * Adds a free-standing imported static mesh scaled so its longest side is LongestMetres. bLongAxisUp turns that side to point up (swords, spears),
	 * bFaceForward turns the thinnest horizontal side to face +X (shields). Returns a holder to move / rotate / hide, or null when not imported.
	 */
	USceneComponent* AddStaticModel(const FString& Folder, const FString& Key, float LongestMetres, bool bLongAxisUp, bool bFaceForward = false);

	/** The imported weapon an enemy carries (null when none / not imported); SyncEnemy swings it. */
	UPROPERTY() TObjectPtr<USceneComponent> Weapon;

	/** Body motion for the imported model, pivoting at the feet: offset (metres, actor-local), rotation (degrees) and a height multiplier (squash / stretch). */
	void SetMotion(const FVector& OffsetM, const FRotator& Rot, float ScaleZ = 1.f);

	/** Sim position (metres, game plane) + height above ground (metres) + facing angle (radians, 0 = +X). */
	void Place(const FVector& WorldCm, float FacingRad);

private:
	UPROPERTY() TObjectPtr<USceneComponent> Pivot;
	UPROPERTY() TArray<TObjectPtr<UStaticMeshComponent>> Parts;
	UPROPERTY() TArray<TObjectPtr<UMaterialInstanceDynamic>> Mats;
	UPROPERTY() TObjectPtr<USceneComponent> Model;       // the imported mesh itself
	UPROPERTY() TObjectPtr<USceneComponent> Rig;         // feet-level holder SetMotion moves
	UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> FlashMat;
	TArray<FLinearColor> BaseColors;
	bool bFlash = false;
	bool bShadows = true;
};
