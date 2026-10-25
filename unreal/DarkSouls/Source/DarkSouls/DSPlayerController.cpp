#include "DSPlayerController.h"
#include "DSGame.h"
#include "Components/InputComponent.h"
#include "Engine/GameViewportClient.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"

ADSPlayerController::ADSPlayerController()
{
	bShowMouseCursor = false;
	PrimaryActorTick.bCanEverTick = true;
}

ADSGame* ADSPlayerController::GetGame()
{
	if (!Game.IsValid()) Game = Cast<ADSGame>(UGameplayStatics::GetActorOfClass(this, ADSGame::StaticClass()));
	return Game.Get();
}

void ADSPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();
	InputComponent->BindTouch(IE_Pressed, this, &ADSPlayerController::TouchDown);
	InputComponent->BindTouch(IE_Released, this, &ADSPlayerController::TouchUp);
	InputComponent->BindKey(EKeys::J, IE_Pressed, this, &ADSPlayerController::KeyAttack);
	InputComponent->BindKey(EKeys::SpaceBar, IE_Pressed, this, &ADSPlayerController::KeyAttack);
	InputComponent->BindKey(EKeys::K, IE_Pressed, this, &ADSPlayerController::KeyRoll);
	InputComponent->BindKey(EKeys::E, IE_Pressed, this, &ADSPlayerController::KeyEstus);
	InputComponent->BindKey(EKeys::U, IE_Pressed, this, &ADSPlayerController::KeySkill1);
	InputComponent->BindKey(EKeys::One, IE_Pressed, this, &ADSPlayerController::KeySkill1);
	InputComponent->BindKey(EKeys::I, IE_Pressed, this, &ADSPlayerController::KeySkill2);
	InputComponent->BindKey(EKeys::Two, IE_Pressed, this, &ADSPlayerController::KeySkill2);
	InputComponent->BindKey(EKeys::Q, IE_Pressed, this, &ADSPlayerController::KeySwap);
	InputComponent->BindKey(EKeys::Escape, IE_Pressed, this, &ADSPlayerController::KeyPause);
	InputComponent->BindKey(EKeys::Enter, IE_Pressed, this, &ADSPlayerController::KeyTap);
	InputComponent->BindKey(EKeys::T, IE_Pressed, this, &ADSPlayerController::KeyTorch);
	InputComponent->BindKey(EKeys::F, IE_Pressed, this, &ADSPlayerController::KeyCommand);
	InputComponent->BindKey(EKeys::M, IE_Pressed, this, &ADSPlayerController::KeyMap);
}

void ADSPlayerController::KeyAttack() { if (ADSGame* G = GetGame()) { if (G->bDialogActive || G->State == EDSState::Dead || G->State == EDSState::Win) G->TapScreen(); else G->PressAttack(); } }
void ADSPlayerController::KeyRoll() { if (ADSGame* G = GetGame()) G->PressRoll(); }
void ADSPlayerController::KeyEstus() { if (ADSGame* G = GetGame()) G->PressEstus(); }
void ADSPlayerController::KeySkill1() { if (ADSGame* G = GetGame()) G->PressSkill(0); }
void ADSPlayerController::KeySkill2() { if (ADSGame* G = GetGame()) G->PressSkill(1); }
void ADSPlayerController::KeySwap() { if (ADSGame* G = GetGame()) G->CycleWeapon(); }
void ADSPlayerController::KeyPause() { if (ADSGame* G = GetGame()) G->TogglePause(); }
void ADSPlayerController::KeyTorch() { if (ADSGame* G = GetGame()) G->TorchToggle(); }
void ADSPlayerController::KeyCommand() { if (ADSGame* G = GetGame()) G->CivCommand(); }
void ADSPlayerController::KeyMap() { if (ADSGame* G = GetGame()) G->ToggleMap(); }
void ADSPlayerController::KeyTap() { if (ADSGame* G = GetGame()) G->TapScreen(); }

void ADSPlayerController::TouchDown(ETouchIndex::Type Finger, FVector Loc)
{
	ADSGame* G = GetGame();
	if (!G) return;
	const FVector2D P(Loc.X, Loc.Y);
	const FDSButton* B = G->HitTest(P);
	if (B)
	{
		if (!B->bEnabled) return;
		const FString& Id = B->Id;
		if (Id == TEXT("atk")) G->PressAttack();
		else if (Id == TEXT("roll")) G->PressRoll();
		else if (Id == TEXT("est")) G->PressEstus();
		else if (Id == TEXT("sk0")) G->PressSkill(0);
		else if (Id == TEXT("sk1")) G->PressSkill(1);
		else if (Id == TEXT("blk")) { Held.Add((int32)Finger, Id); }
		else G->OnButton(Id);
		return;
	}
	if (G->bMapOpen)
	{
		if (MapFinger < 0) { MapFinger = (int32)Finger; MapLast = P; }
		return;
	}
	if (G->State != EDSState::Title && (G->bDialogActive || G->State == EDSState::Dead || G->State == EDSState::Win || G->State == EDSState::Comic))
	{
		G->TapScreen();
		return;
	}
	if (G->State == EDSState::Play && !G->bPaused && !G->bShopOpen && StickFinger < 0)
	{
		int32 SX = 0, SY = 0;
		GetViewportSize(SX, SY);
		if (P.X >= SX * 0.55f && G->MazeK > 0.3f && LookFinger < 0)
		{
			LookFinger = (int32)Finger;
			LookLast = P;
		}
		if (P.X < SX * 0.55f)
		{
			StickFinger = (int32)Finger;
			StickOrigin = StickPos = P;
			bStickActive = true;
			StickMax = FMath::Max(40.f, SY * 0.1f);
		}
	}
}

void ADSPlayerController::TouchUp(ETouchIndex::Type Finger, FVector Loc)
{
	if ((int32)Finger == StickFinger)
	{
		StickFinger = -1;
		bStickActive = false;
	}
	if ((int32)Finger == LookFinger) LookFinger = -1;
	if ((int32)Finger == MapFinger) MapFinger = -1;
	Held.Remove((int32)Finger);
}

void ADSPlayerController::PlayerTick(float DeltaTime)
{
	Super::PlayerTick(DeltaTime);
	ADSGame* G = GetGame();
	if (!G) return;
	if (!bViewSet && G->Camera)
	{
		SetViewTarget(G->Camera);
		bViewSet = true;
	}

	// drag on the right side: look around inside the labyrinth; drag on the map: pan it
	if (LookFinger >= 0)
	{
		float X = 0.f, Y = 0.f;
		bool bDown = false;
		GetInputTouchState((ETouchIndex::Type)LookFinger, X, Y, bDown);
		if (bDown) { G->CamYaw -= (X - LookLast.X) * 0.006f; LookLast = FVector2D(X, Y); }
		else LookFinger = -1;
	}
	if (MapFinger >= 0)
	{
		float X = 0.f, Y = 0.f;
		bool bDown = false;
		GetInputTouchState((ETouchIndex::Type)MapFinger, X, Y, bDown);
		if (bDown) { G->MapCentre -= (FVector2D(X, Y) - MapLast) / FMath::Max(G->MapScale, 0.05f); MapLast = FVector2D(X, Y); }
		else MapFinger = -1;
	}
	if (G->MazeK > 0.3f)
	{
		if (IsInputKeyDown(EKeys::Z)) G->CamYaw += 1.8f * DeltaTime;
		if (IsInputKeyDown(EKeys::C)) G->CamYaw -= 1.8f * DeltaTime;
	}
	FVector2D Move = FVector2D::ZeroVector;
	if (StickFinger >= 0)
	{
		float X = 0.f, Y = 0.f;
		bool bDown = false;
		GetInputTouchState((ETouchIndex::Type)StickFinger, X, Y, bDown);
		if (bDown)
		{
			StickPos = FVector2D(X, Y);
			FVector2D D = StickPos - StickOrigin;
			if (D.Size() > StickMax)
			{
				StickOrigin += D.GetSafeNormal() * (D.Size() - StickMax);   // the stick floats after the thumb
				D = StickPos - StickOrigin;
			}
			Move = D / StickMax;
		}
		else
		{
			StickFinger = -1;
			bStickActive = false;
		}
	}
	if (IsInputKeyDown(EKeys::A) || IsInputKeyDown(EKeys::Left)) Move.X -= 1.f;
	if (IsInputKeyDown(EKeys::D) || IsInputKeyDown(EKeys::Right)) Move.X += 1.f;
	if (IsInputKeyDown(EKeys::W) || IsInputKeyDown(EKeys::Up)) Move.Y -= 1.f;
	if (IsInputKeyDown(EKeys::S) || IsInputKeyDown(EKeys::Down)) Move.Y += 1.f;
	if (Move.Size() > 1.f) Move = Move.GetSafeNormal();
	G->MoveInput = Move;

	bool bBlock = IsInputKeyDown(EKeys::L) || IsInputKeyDown(EKeys::LeftShift);
	for (const TPair<int32, FString>& H : Held) if (H.Value == TEXT("blk")) bBlock = true;
	G->bBlockHeld = bBlock;
}
