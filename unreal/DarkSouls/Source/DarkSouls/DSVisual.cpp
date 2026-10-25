#include "DSVisual.h"
#include "Components/StaticMeshComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"

ADSVisual::ADSVisual()
{
	PrimaryActorTick.bCanEverTick = false;
	Pivot = CreateDefaultSubobject<USceneComponent>(TEXT("Pivot"));
	SetRootComponent(Pivot);
	Pivot->SetMobility(EComponentMobility::Movable);
}

int32 ADSVisual::AddPart(EDSShape Shape, const FVector& LocalMetres, const FVector& ScaleMetres, const FLinearColor& Color)
{
	static const TCHAR* Paths[] = {
		TEXT("/Engine/BasicShapes/Cube.Cube"), TEXT("/Engine/BasicShapes/Sphere.Sphere"),
		TEXT("/Engine/BasicShapes/Cylinder.Cylinder"), TEXT("/Engine/BasicShapes/Cone.Cone") };
	UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, Paths[(int32)Shape]);
	UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));

	UStaticMeshComponent* C = NewObject<UStaticMeshComponent>(this);
	C->SetMobility(EComponentMobility::Movable);
	C->SetStaticMesh(Mesh);
	C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	C->SetCastShadow(bShadows);
	C->SetupAttachment(Pivot);
	C->RegisterComponent();
	C->SetRelativeLocation(LocalMetres * 100.0);
	C->SetRelativeScale3D(ScaleMetres);        // the engine primitives are 100 cm across, so metres == scale

	UMaterialInstanceDynamic* M = UMaterialInstanceDynamic::Create(Base, this);
	if (M)
	{
		M->SetVectorParameterValue(TEXT("Color"), Color);
		C->SetMaterial(0, M);
	}
	Parts.Add(C);
	Mats.Add(M);
	BaseColors.Add(Color);
	return Parts.Num() - 1;
}

void ADSVisual::SetPartColor(int32 I, const FLinearColor& Col)
{
	if (!Mats.IsValidIndex(I)) return;
	BaseColors[I] = Col;
	if (Mats[I] && !bFlash) Mats[I]->SetVectorParameterValue(TEXT("Color"), Col);
}

void ADSVisual::SetAllColor(const FLinearColor& Col)
{
	for (int32 i = 0; i < Mats.Num(); i++) SetPartColor(i, Col);
}

void ADSVisual::SetFlash(bool bOn)
{
	if (bOn == bFlash) return;
	bFlash = bOn;
	for (int32 i = 0; i < Mats.Num(); i++)
		if (Mats[i]) Mats[i]->SetVectorParameterValue(TEXT("Color"), bOn ? FLinearColor(3.f, 3.f, 3.f) : BaseColors[i]);
}

void ADSVisual::SetShadows(bool bOn)
{
	bShadows = bOn;
	for (UStaticMeshComponent* C : Parts) if (C) C->SetCastShadow(bOn);
}

void ADSVisual::SetCollisionOff()
{
	SetActorEnableCollision(false);
}

void ADSVisual::Place(const FVector& WorldCm, float FacingRad)
{
	SetActorLocationAndRotation(WorldCm, FRotator(0.0, FMath::RadiansToDegrees(FacingRad), 0.0));
}

UInstancedStaticMeshComponent* ADSVisual::AddInstanced(EDSShape Shape, const FLinearColor& Color)
{
	static const TCHAR* Paths[] = {
		TEXT("/Engine/BasicShapes/Cube.Cube"), TEXT("/Engine/BasicShapes/Sphere.Sphere"),
		TEXT("/Engine/BasicShapes/Cylinder.Cylinder"), TEXT("/Engine/BasicShapes/Cone.Cone") };
	UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, Paths[(int32)Shape]);
	UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
	UInstancedStaticMeshComponent* C = NewObject<UInstancedStaticMeshComponent>(this);
	C->SetMobility(EComponentMobility::Movable);
	C->SetStaticMesh(Mesh);
	C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	C->SetCastShadow(false);
	C->SetupAttachment(Pivot);
	C->RegisterComponent();
	if (UMaterialInstanceDynamic* M = UMaterialInstanceDynamic::Create(Base, this))
	{
		M->SetVectorParameterValue(TEXT("Color"), Color);
		C->SetMaterial(0, M);
	}
	return C;
}

void ADSVisual::AddInstance(UInstancedStaticMeshComponent* C, const FVector& WorldCm, const FVector& ScaleMetres, float YawRad)
{
	if (C) C->AddInstance(FTransform(FRotator(0.0, FMath::RadiansToDegrees(YawRad), 0.0), WorldCm, ScaleMetres), true);
}
