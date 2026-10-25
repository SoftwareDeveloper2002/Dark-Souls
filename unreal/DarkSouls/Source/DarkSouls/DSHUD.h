// Canvas HUD: title screen, bars, on-screen buttons, dialogue, bonfire shop, pause and death screens.
// Port of the _draw_hud code in game.gd, touch_controls.gd, dialogue.gd and shop.gd.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "DSHUD.generated.h"

class ADSGame;

UCLASS()
class DARKSOULS_API ADSHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void DrawHUD() override;

private:
	void Txt(const FString& S, float X, float Y, float Scale, const FLinearColor& C, int32 Align = 0);   // 0 left, 1 centre, 2 right
	void Box(float X, float Y, float W, float H, const FLinearColor& Fill, const FLinearColor& Border = FLinearColor(0, 0, 0, 0));
	void Bar(float X, float Y, float W, float H, float Frac, float Trail, const FLinearColor& Col);
	void Button(const FString& Id, const FString& Label, float Cx, float Cy, float W, float H, bool bEnabled = true, float Cooldown = 0.f, bool bBig = false);

	void DrawTitle();
	void DrawPlay();
	void DrawControls();
	void DrawDialog();
	void DrawShop();
	void DrawPause();
	void DrawEnd();
	void DrawMap();
	void DrawMinimap();
	void DrawComic();
	void DrawCredits();
	void DrawSpeeches();
	void DrawCivBars();
	float Wrap(const FString& Text, float X, float Y, float W, float Scale, const FLinearColor& C);   // returns the y below the last line
	void ShopRow(float X, float& Y, float W, const FString& Title, const FString& Level, const FString& Effect, const FString& Btn, bool bEnabled, const FString& Id);

	ADSGame* G = nullptr;
	float S = 1.f;           // UI scale (screen height / 720)
	float VW = 0.f, VH = 0.f;
	UFont* Font = nullptr;
};
