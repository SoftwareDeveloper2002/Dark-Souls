// On-screen mobile controls: floating joystick (left half) + Attack / Roll / Block / Estus / Skill buttons (right).
// Port of touch_controls.gd. The mouse stands in for a finger on desktop (bUseMouseForTouch in DefaultInput.ini),
// and the keyboard works as in the Godot build: WASD / arrows, J or Space attack, K roll, E estus, U/1 and I/2 skills, Q swap, Esc pause.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "DSPlayerController.generated.h"

class ADSGame;

UCLASS()
class DARKSOULS_API ADSPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	ADSPlayerController();
	virtual void SetupInputComponent() override;
	virtual void PlayerTick(float DeltaTime) override;

	FVector2D StickOrigin = FVector2D::ZeroVector, StickPos = FVector2D::ZeroVector;
	bool bStickActive = false;
	float StickMax = 70.f;

private:
	ADSGame* GetGame();
	void TouchDown(ETouchIndex::Type Finger, FVector Loc);
	void TouchUp(ETouchIndex::Type Finger, FVector Loc);
	void KeyAttack();
	void KeyRoll();
	void KeyEstus();
	void KeySkill1();
	void KeySkill2();
	void KeySwap();
	void KeyPause();
	void KeyTap();
	void KeyTorch();
	void KeyCommand();
	void KeyMap();

	TWeakObjectPtr<ADSGame> Game;
	int32 StickFinger = -1;
	int32 LookFinger = -1, MapFinger = -1;
	FVector2D LookLast = FVector2D::ZeroVector, MapLast = FVector2D::ZeroVector;
	TMap<int32, FString> Held;       // finger -> button id
	bool bBlockTouch = false;
	bool bViewSet = false;
};
