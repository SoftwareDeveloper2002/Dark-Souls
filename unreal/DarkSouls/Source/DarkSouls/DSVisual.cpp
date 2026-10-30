#include "DSVisual.h"
#include "Components/StaticMeshComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "Components/MeshComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/SkeletalMesh.h"
#include "AssetRegistry/AssetRegistryModule.h"

// Finds an imported mesh: any static / skeletal mesh whose package path has `Key` as a folder or file name under /Game/Models/<Folder>.
static UObject* DSFindModel(const FString& Folder, const FString& Key)
{
	static TMap<FString, TWeakObjectPtr<UObject>> Cache;
	const FString Id = Folder + TEXT("/") + Key;
	if (TWeakObjectPtr<UObject>* Hit = Cache.Find(Id))
		if (Hit->IsValid()) return Hit->Get();

	FAssetRegistryModule& Reg = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
	TArray<FAssetData> Assets;
	Reg.Get().GetAssetsByPath(FName(*(TEXT("/Game/Models/") + Folder)), Assets, true);
	const FString Seg = TEXT("/") + Key.ToLower();
	UObject* Best = nullptr;
	for (const FAssetData& A : Assets)
	{
		const bool bSkel = A.AssetClassPath == USkeletalMesh::StaticClass()->GetClassPathName();
		const bool bStat = A.AssetClassPath == UStaticMesh::StaticClass()->GetClassPathName();
		if (!bSkel && !bStat) continue;
		const FString Pkg = A.PackageName.ToString().ToLower();
		if (!(Pkg.Contains(Seg + TEXT("/")) || Pkg.EndsWith(Seg))) continue;
		if (UObject* O = A.GetAsset())
		{
			if (!Best || bSkel) Best = O;        // prefer the skinned mesh when a file produced both
		}
	}
	if (Best) Cache.Add(Id, Best);
	return Best;
}

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

bool ADSVisual::AttachModel(const FString& Folder, const FString& Key, float HeightMetres, const TArray<int32>& HidePrimitives, float YawOffsetDeg)
{
	UObject* Asset = DSFindModel(Folder, Key);
	if (!Asset) return false;

	FBoxSphereBounds Bounds;
	UMeshComponent* MC = nullptr;
	if (USkeletalMesh* SK = Cast<USkeletalMesh>(Asset))
	{
		USkeletalMeshComponent* C = NewObject<USkeletalMeshComponent>(this);
		C->SetSkeletalMesh(SK);
		C->SetAnimationMode(EAnimationMode::AnimationSingleNode);   // no animation asset: stays in its rest pose, the actor itself leans / swings
		Bounds = SK->GetBounds();
		MC = C;
	}
	else if (UStaticMesh* SM = Cast<UStaticMesh>(Asset))
	{
		UStaticMeshComponent* C = NewObject<UStaticMeshComponent>(this);
		C->SetStaticMesh(SM);
		Bounds = SM->GetBounds();
		MC = C;
	}
	if (!MC) return false;

	// the rig sits at the feet, so leaning / bobbing / squashing pivots there rather than on the mesh origin
	Rig = NewObject<USceneComponent>(this);
	Rig->SetMobility(EComponentMobility::Movable);
	Rig->SetupAttachment(Pivot);
	Rig->RegisterComponent();
	MC->SetMobility(EComponentMobility::Movable);
	MC->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	MC->SetCastShadow(bShadows);
	MC->SetupAttachment(Rig);
	MC->RegisterComponent();
	// scale to the requested height (the importer gives centimetres), stand it on the ground and turn it to face +X
	const float HeightCm = FMath::Max(Bounds.BoxExtent.Z * 2.f, 1.f);
	const float S = (HeightMetres * 100.f) / HeightCm;
	MC->SetRelativeScale3D(FVector(S));
	MC->SetRelativeLocation(FVector(0.f, 0.f, -(Bounds.Origin.Z - Bounds.BoxExtent.Z) * S));
	MC->SetRelativeRotation(FRotator(0.f, YawOffsetDeg, 0.f));
	Model = MC;
	for (int32 I : HidePrimitives)
		if (Parts.IsValidIndex(I) && Parts[I]) Parts[I]->SetVisibility(false);
	return true;
}

USceneComponent* ADSVisual::AddStaticModel(const FString& Folder, const FString& Key, float LongestMetres, bool bLongAxisUp, bool bFaceForward)
{
	UStaticMesh* SM = Cast<UStaticMesh>(DSFindModel(Folder, Key));
	if (!SM) return nullptr;
	const FBoxSphereBounds B = SM->GetBounds();
	const FVector Ext = B.BoxExtent;
	int32 Axis = 0;
	if (Ext.Y > Ext[Axis]) Axis = 1;
	if (Ext.Z > Ext[Axis]) Axis = 2;
	const float S = (LongestMetres * 100.f) / FMath::Max(Ext[Axis] * 2.f, 1.f);

	FQuat Q = FQuat::Identity;
	if (bLongAxisUp && Axis != 2)
		Q = FQuat::FindBetweenNormals(Axis == 0 ? FVector::XAxisVector : FVector::YAxisVector, FVector::ZAxisVector);
	else if (bFaceForward && Ext.Y < Ext.X)
		Q = FQuat(FVector::ZAxisVector, PI * 0.5);

	USceneComponent* Holder = NewObject<USceneComponent>(this);
	Holder->SetMobility(EComponentMobility::Movable);
	Holder->SetupAttachment(Pivot);
	Holder->RegisterComponent();

	UStaticMeshComponent* C = NewObject<UStaticMeshComponent>(this);
	C->SetMobility(EComponentMobility::Movable);
	C->SetStaticMesh(SM);
	C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	C->SetCastShadow(bShadows);
	C->SetupAttachment(Holder);
	C->RegisterComponent();
	C->SetRelativeScale3D(FVector(S));
	C->SetRelativeRotation(Q);
	C->SetRelativeLocation(-Q.RotateVector(B.Origin) * S);     // centre the mesh on the holder
	return Holder;
}

void ADSVisual::SetMotion(const FVector& OffsetM, const FRotator& Rot, float ScaleZ)
{
	if (!Rig) return;
	Rig->SetRelativeLocation(OffsetM * 100.0);
	Rig->SetRelativeRotation(Rot);
	Rig->SetRelativeScale3D(FVector(1.f, 1.f, ScaleZ));
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
	// imported models carry their own materials, so the hit flash is a bright overlay drawn on top of them
	if (UMeshComponent* MM = Cast<UMeshComponent>(Model))
	{
		if (bOn && !FlashMat)
			if (UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial")))
			{
				FlashMat = UMaterialInstanceDynamic::Create(Base, this);
				if (FlashMat) FlashMat->SetVectorParameterValue(TEXT("Color"), FLinearColor(3.f, 3.f, 3.f));
			}
		MM->SetOverlayMaterial(bOn ? FlashMat.Get() : nullptr);
	}
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

UInstancedStaticMeshComponent* ADSVisual::AddInstancedModel(const FString& Folder, const FString& Key, float& OutHeightM, float& OutBaseM)
{
	UStaticMesh* SM = Cast<UStaticMesh>(DSFindModel(Folder, Key));
	if (!SM) return nullptr;
	const FBoxSphereBounds B = SM->GetBounds();
	OutHeightM = FMath::Max(B.BoxExtent.Z * 2.f, 1.f) / 100.f;
	OutBaseM = (B.Origin.Z - B.BoxExtent.Z) / 100.f;
	UInstancedStaticMeshComponent* C = NewObject<UInstancedStaticMeshComponent>(this);
	C->SetMobility(EComponentMobility::Movable);
	C->SetStaticMesh(SM);
	C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	C->SetCastShadow(false);
	C->SetupAttachment(Pivot);
	C->RegisterComponent();
	return C;
}

void ADSVisual::AddInstance(UInstancedStaticMeshComponent* C, const FVector& WorldCm, const FVector& ScaleMetres, float YawRad)
{
	if (C) C->AddInstance(FTransform(FRotator(0.0, FMath::RadiansToDegrees(YawRad), 0.0), WorldCm, ScaleMetres), true);
}
