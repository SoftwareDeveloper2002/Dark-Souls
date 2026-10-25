#include "DSHUD.h"
#include "DSGame.h"
#include "DSPlayerController.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Kismet/GameplayStatics.h"

namespace
{
	const FLinearColor Bone(0.85f, 0.81f, 0.72f), Ember(0.91f, 0.54f, 0.17f), Gold(0.54f, 0.48f, 0.33f), Ink(0.02f, 0.018f, 0.015f, 0.92f);
}

void ADSHUD::Txt(const FString& Str, float X, float Y, float Scale, const FLinearColor& C, int32 Align)
{
	float W = 0.f, H = 0.f;
	GetTextSize(Str, W, H, Font, Scale);
	if (Align == 1) X -= W * 0.5f; else if (Align == 2) X -= W;
	DrawText(Str, FLinearColor(0, 0, 0, C.A * 0.8f), X + 1.5f * S, Y + 1.5f * S, Font, Scale);
	DrawText(Str, C, X, Y, Font, Scale);
}

void ADSHUD::Box(float X, float Y, float W, float H, const FLinearColor& Fill, const FLinearColor& Border)
{
	if (Border.A > 0.f)
	{
		const float T = FMath::Max(1.f, 2.f * S);
		DrawRect(Border, X - T, Y - T, W + 2 * T, H + 2 * T);
	}
	DrawRect(Fill, X, Y, W, H);
}

void ADSHUD::Bar(float X, float Y, float W, float H, float Frac, float Trail, const FLinearColor& Col)
{
	Box(X, Y, W, H, FLinearColor(0.f, 0.f, 0.f, 0.7f), Gold);
	if (Trail > Frac) DrawRect(FLinearColor(0.9f, 0.85f, 0.7f, 0.8f), X, Y, W * FMath::Clamp(Trail, 0.f, 1.f), H);
	DrawRect(Col, X, Y, W * FMath::Clamp(Frac, 0.f, 1.f), H);
}

void ADSHUD::Button(const FString& Id, const FString& Label, float Cx, float Cy, float W, float H, bool bEnabled, float Cooldown, bool bBig)
{
	const float X = Cx - W * 0.5f, Y = Cy - H * 0.5f;
	Box(X, Y, W, H, FLinearColor(0.04f, 0.035f, 0.03f, bEnabled ? 0.75f : 0.45f), bEnabled ? Gold : FLinearColor(0.3f, 0.28f, 0.22f, 0.6f));
	if (Cooldown > 0.f) DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.6f), X, Y + H * (1.f - Cooldown), W, H * Cooldown);
	Txt(Label, Cx, Cy - 8.f * S * (bBig ? 1.4f : 1.f), bBig ? 1.3f * S : 0.9f * S, bEnabled ? Bone : FLinearColor(Bone.R, Bone.G, Bone.B, 0.45f), 1);
	G->AddButton(Id, FBox2D(FVector2D(X, Y), FVector2D(X + W, Y + H)), bEnabled);
}

void ADSHUD::DrawHUD()
{
	Super::DrawHUD();
	if (!G) G = Cast<ADSGame>(UGameplayStatics::GetActorOfClass(this, ADSGame::StaticClass()));
	if (!G || !Canvas) return;
	VW = Canvas->SizeX;
	VH = Canvas->SizeY;
	S = VH / 720.f;
	Font = GEngine->GetMediumFont();

	if (G->State == EDSState::Title) { DrawTitle(); return; }
	if (G->State == EDSState::Comic) { DrawComic(); return; }
	if (G->FlashAmount > 0.01f) DrawRect(FLinearColor(0.8f, 0.85f, 1.f, FMath::Min(G->FlashAmount * 0.35f, 0.5f)), 0, 0, VW, VH);
	if (G->bMapOpen) { DrawMap(); return; }
	DrawPlay();
	DrawSpeeches();
	DrawCivBars();
	if (G->State == EDSState::Play && !G->bDialogActive && !G->bShopOpen && !G->bPaused) { DrawMinimap(); DrawControls(); }
	if (G->bDialogActive) DrawDialog();
	if (G->bShopOpen) DrawShop();
	if (G->bPaused) DrawPause();
	if (G->State == EDSState::Dead || G->State == EDSState::Win) DrawEnd();
}

// ------------------------------------------------------------------ title

void ADSHUD::DrawTitle()
{
	DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.55f), 0, 0, VW, VH);
	Txt(TEXT("DARK SOULS"), VW * 0.5f, VH * 0.2f, 5.f * S, FLinearColor(0.85f, 0.7f, 0.35f), 1);
	Txt(TEXT("The Ashen Order"), VW * 0.5f, VH * 0.2f + 90.f * S, 1.4f * S, Bone, 1);
	float Y = VH * 0.55f;
	Button(TEXT("new"), TEXT("NEW GAME"), VW * 0.5f, Y, 320.f * S, 64.f * S, true, 0.f, true);
	if (G->bHasSaveCached)
	{
		Y += 84.f * S;
		Button(TEXT("continue"), TEXT("CONTINUE"), VW * 0.5f, Y, 320.f * S, 64.f * S, true, 0.f, true);
	}
}

// ------------------------------------------------------------------ in-game HUD

void ADSHUD::DrawPlay()
{
	const float M = 24.f * S;
	Bar(M, M, 360.f * S, 18.f * S, G->PHp / G->PMaxHp, G->HpTrail / G->PMaxHp, FLinearColor(0.65f, 0.1f, 0.08f));
	Bar(M, M + 26.f * S, 280.f * S, 11.f * S, G->PSt / G->PMaxSt, 0.f, FLinearColor(0.25f, 0.6f, 0.3f));
	Txt(FString::Printf(TEXT("SOULS  %d"), G->Souls), M, M + 46.f * S, 1.0f * S, FLinearColor(0.95f, 0.82f, 0.48f));
	Txt(FString::Printf(TEXT("POTIONS  %d"), G->Flasks), M, M + 68.f * S, 0.9f * S, Ember);
	if (G->WeaponsOwned[(int32)EDSWeapon::Gun])
		Txt(G->bUnlimitedAmmo ? FString(TEXT("AMMO  INF")) : FString::Printf(TEXT("AMMO  %d"), G->Ammo), M, M + 88.f * S, 0.9f * S, FLinearColor(0.54f, 0.85f, 1.f));

	if (G->State == EDSState::Play && !G->Q.Title.IsEmpty())
	{
		Txt(FString::Printf(TEXT("QUEST %d - %s"), G->QuestN, *G->Q.Title.ToUpper()), VW * 0.5f, M, 1.0f * S, Bone, 1);
		Txt(G->QuestLine(), VW * 0.5f, M + 22.f * S, 0.9f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.75f), 1);
		if (G->AwayWarn > 1.f) Txt(TEXT("RETURN TO THE FIGHT!"), VW * 0.5f, M + 46.f * S, 1.1f * S, FLinearColor(1.f, 0.4f, 0.3f), 1);
		// objective marker: arrow pointing along the road to the quest site
		if (!G->bQArrived || G->Q.Kind == EDSQuestKind::Boss)
		{
			const FVector2D Off = G->Site - G->PPos;
			const float D = Off.Size();
			if (D > 12.f && !G->bQArrived)
			{
				const FVector2D Dir = Off.GetSafeNormal();
				const FVector2D C(VW * 0.5f, VH * 0.5f);
				const FVector2D P = C + Dir * VH * 0.32f;
				DrawLine(P.X, P.Y, P.X - Dir.X * 22.f * S + Dir.Y * 10.f * S, P.Y - Dir.Y * 22.f * S - Dir.X * 10.f * S, Ember, 3.f);
				DrawLine(P.X, P.Y, P.X - Dir.X * 22.f * S - Dir.Y * 10.f * S, P.Y - Dir.Y * 22.f * S + Dir.X * 10.f * S, Ember, 3.f);
				Txt(FString::Printf(TEXT("%d m"), (int32)D), P.X, P.Y + 12.f * S, 0.8f * S, Ember, 1);
			}
		}
	}

	// boss bar
	for (const FDSEnemyPtr& E : G->Enemies)
	{
		if (!E->bBoss || E->bDead || E->Mode != EDSMode::Alert) continue;
		const float W = FMath::Min(VW * 0.6f, 700.f * S);
		const float X = (VW - W) * 0.5f, Y = VH - 60.f * S;
		Txt(DSData::Enemy(E->Type).Name, VW * 0.5f, Y - 26.f * S, 1.1f * S, Bone, 1);
		Bar(X, Y, W, 16.f * S, E->Hp / E->MaxHp, 0.f, FLinearColor(0.6f, 0.08f, 0.08f));
		if (E->Shield > 0.f) Bar(X, Y - 8.f * S, W, 6.f * S, E->Shield / FMath::Max(E->ShieldMax, 1.f), 0.f, FLinearColor(0.2f, 0.6f, 0.95f));
		break;
	}

	for (const FDSFloater& F : G->Floaters)
	{
		FVector2D Sp;
		if (!G->WorldToScreen(F.Pos + FVector(0, 0, F.Age * 120.f), Sp)) continue;
		FLinearColor C = F.Col;
		C.A = 1.f - FMath::Clamp((F.Age - F.Life * 0.6f) / (F.Life * 0.4f), 0.f, 1.f);
		Txt(F.Text, Sp.X, Sp.Y, 1.1f * S, C, 1);
	}

	if (G->BannerT > 0.f && !G->BannerText.IsEmpty())
	{
		const float A = FMath::Clamp(G->BannerT / 0.5f, 0.f, 1.f);
		DrawRect(FLinearColor(0, 0, 0, 0.45f * A), 0, VH * 0.3f, VW, 110.f * S);
		Txt(G->BannerText, VW * 0.5f, VH * 0.3f + 20.f * S, 2.4f * S, FLinearColor(0.85f, 0.7f, 0.35f, A), 1);
		if (!G->BannerSub.IsEmpty()) Txt(G->BannerSub, VW * 0.5f, VH * 0.3f + 74.f * S, 1.0f * S, FLinearColor(Bone.R, Bone.G, Bone.B, A), 1);
	}
}

void ADSHUD::DrawControls()
{
	const float Atk = 130.f * S;
	Button(TEXT("atk"), G->ControlLabel(), VW - 130.f * S, VH - 140.f * S, Atk, Atk, true, 0.f, true);
	Button(TEXT("roll"), TEXT("ROLL"), VW - 290.f * S, VH - 90.f * S, 92.f * S, 92.f * S, G->PSt >= 20.f);
	Button(TEXT("blk"), TEXT("BLOCK"), VW - 270.f * S, VH - 215.f * S, 92.f * S, 92.f * S);
	Button(TEXT("est"), FString::Printf(TEXT("ESTUS\n%d"), G->Flasks), VW - 80.f * S, VH - 290.f * S, 84.f * S, 84.f * S, G->Flasks > 0);
	const int32 W = (int32)G->Equipped;
	for (int32 Slot = 0; Slot < 2; Slot++)
	{
		const FDSSkillDef& D = DSData::Skill(G->Equipped, Slot);
		const bool bOk = G->Skills[W][Slot].bUnlocked;
		Button(Slot == 0 ? TEXT("sk0") : TEXT("sk1"), bOk ? FString(D.Label) : FString(TEXT("LOCKED")),
			VW - (410.f + 100.f * Slot) * S, VH - (80.f + 70.f * Slot) * S, 84.f * S, 84.f * S, bOk && G->SkillReady(Slot) , bOk ? G->SkillCdFrac(Slot) : 0.f);
	}
	if (G->CanCycle()) Button(TEXT("swap"), TEXT("SWAP"), VW - 70.f * S, 130.f * S, 76.f * S, 60.f * S);
	Button(TEXT("pause"), TEXT("II"), VW - 50.f * S, 50.f * S, 56.f * S, 56.f * S);
	if (G->bTorchActive) Button(TEXT("torch"), G->bTorchHeld ? TEXT("DROP") : (G->TorchCanPick() ? TEXT("PICK UP") : TEXT("TORCH")), VW - 70.f * S, 215.f * S, 100.f * S, 60.f * S, G->bTorchHeld || G->TorchCanPick());
	if (G->CivTotal > 0 && !G->CivAllSaved() && G->MazeMargin(G->PPos) > 0.f)
	{
		const int32 Following = G->CivCount(1) + G->CivCount(2);
		Button(TEXT("cmd"), Following > 0 ? (G->CivCount(1) > 0 ? TEXT("STAY") : TEXT("FOLLOW")) : TEXT("COMMAND"), VW - 70.f * S, 285.f * S, 100.f * S, 60.f * S, Following > 0);
	}

	if (ADSPlayerController* PC = Cast<ADSPlayerController>(GetOwningPlayerController()))
		if (PC->bStickActive)
		{
			const float R = PC->StickMax;
			Box(PC->StickOrigin.X - R, PC->StickOrigin.Y - 1.f, 2.f * R, 2.f, FLinearColor(1, 1, 1, 0.15f));
			Box(PC->StickOrigin.X - 1.f, PC->StickOrigin.Y - R, 2.f, 2.f * R, FLinearColor(1, 1, 1, 0.15f));
			Box(PC->StickPos.X - 18.f * S, PC->StickPos.Y - 18.f * S, 36.f * S, 36.f * S, FLinearColor(0.85f, 0.81f, 0.72f, 0.5f), Gold);
		}
}

// ------------------------------------------------------------------ dialogue

void ADSHUD::DrawDialog()
{
	DrawRect(FLinearColor(0, 0, 0, 0.35f), 0, 0, VW, VH);
	const float X = 70.f * S, W = VW - 140.f * S, H = 176.f * S, Y = VH - H - 24.f * S;
	Box(X, Y, W, H, Ink, Gold);
	const FDSLine& L = G->DialogLines[FMath::Clamp(G->DialogIdx, 0, G->DialogLines.Num() - 1)];
	FString Who = L.Who;
	FString Text = L.Text;
	Text = Text.Left((int32)G->DialogShown);
	// portrait frame: the speaker's initial on a coloured plate
	{
		const float Ps = 110.f * S;
		Box(X + 18.f * S, Y + 18.f * S, Ps, Ps, Who == TEXT("ELARA") ? FLinearColor(0.35f, 0.2f, 0.3f) : (Who.IsEmpty() ? FLinearColor(0.1f, 0.1f, 0.14f) : FLinearColor(0.3f, 0.12f, 0.08f)), Gold);
		Txt(Who.IsEmpty() ? FString(TEXT("~")) : Who.Left(1), X + 18.f * S + Ps * 0.5f, Y + 18.f * S + Ps * 0.2f, 4.f * S, Bone, 1);
	}
	if (!Who.IsEmpty()) Txt(Who, X + 150.f * S, Y + 14.f * S, 1.3f * S, FLinearColor(0.95f, 0.82f, 0.48f));
	// word wrap
	const float MaxW = W - 180.f * S;
	float Cx = X + 150.f * S, Cy = Y + 50.f * S;
	TArray<FString> Words;
	Text.ParseIntoArray(Words, TEXT(" "));
	for (const FString& Word : Words)
	{
		float Tw = 0.f, Th = 0.f;
		GetTextSize(Word + TEXT(" "), Tw, Th, Font, 1.05f * S);
		if (Cx + Tw > X + 150.f * S + MaxW) { Cx = X + 150.f * S; Cy += Th + 4.f * S; }
		Txt(Word, Cx, Cy, 1.05f * S, Bone);
		Cx += Tw;
	}
	if (G->DialogShown >= FCString::Strlen(L.Text))
		Txt(TEXT("TAP TO CONTINUE"), X + W - 24.f * S, Y + H - 28.f * S, 0.8f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.5f + 0.4f * FMath::Sin(G->Time * 4.f)), 2);
}

// ------------------------------------------------------------------ shop

void ADSHUD::ShopRow(float X, float& Y, float W, const FString& Title, const FString& Level, const FString& Effect, const FString& Btn, bool bEnabled, const FString& Id)
{
	Txt(Title, X, Y + 10.f * S, 1.0f * S, Bone);
	Txt(Level, X + 250.f * S, Y + 10.f * S, 0.95f * S, FLinearColor(0.95f, 0.82f, 0.48f));
	Txt(Effect, X + 360.f * S, Y + 12.f * S, 0.8f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.65f));
	Button(Id, Btn, X + W - 90.f * S, Y + 22.f * S, 180.f * S, 44.f * S, bEnabled);
	Y += 54.f * S;
}

void ADSHUD::DrawShop()
{
	DrawRect(FLinearColor(0, 0, 0, 0.7f), 0, 0, VW, VH);
	const float W = FMath::Min(VW - 40.f * S, 1000.f * S);
	const float X = (VW - W) * 0.5f;
	Txt(TEXT("BONFIRE"), VW * 0.5f, 14.f * S, 2.f * S, FLinearColor(0.85f, 0.7f, 0.35f), 1);
	Txt(FString::Printf(TEXT("SOULS  %d     POTIONS  %d/%d     KEYS  %d/3%s"), G->Souls, G->Flasks, DSData::MaxPotions, G->Keys,
		G->WeaponsOwned[3] ? *FString::Printf(TEXT("     AMMO  %d"), G->Ammo) : TEXT("")), VW * 0.5f, 62.f * S, 1.0f * S, FLinearColor(0.95f, 0.82f, 0.48f), 1);
	static const TCHAR* Tabs[] = { TEXT("UPGRADES"), TEXT("SKILLS"), TEXT("SUPPLIES"), TEXT("GEAR") };
	for (int32 i = 0; i < 4; i++)
		Button(FString::Printf(TEXT("tab:%d"), i), Tabs[i], VW * 0.5f + (i - 1.5f) * 180.f * S, 112.f * S, 170.f * S, 42.f * S, G->ShopTab != i);

	float Y = 150.f * S;
	const int32 W0 = (int32)G->Equipped;
	const FDSWeaponDef& WD = DSData::Weapon(G->Equipped);
	auto StatRow = [&](int32 I)
	{
		const FDSStatDef& St = DSData::Stats()[I];
		const int32 L = G->Lv[I];
		if (L >= St.Max) ShopRow(X, Y, W, St.Label, TEXT("MAX"), St.Effect, TEXT("MAXED"), false, TEXT("none"));
		else
		{
			const int32 Cost = ADSGame::StatCost(St.BaseCost, L);
			ShopRow(X, Y, W, St.Label, FString::Printf(TEXT("Lv %d/%d"), L, St.Max), St.Effect, FString::Printf(TEXT("BUY  %d"), Cost), G->Souls >= Cost, FString::Printf(TEXT("stat:%d"), I));
		}
	};
	switch (G->ShopTab)
	{
	case 0:
	{
		const int32 T = G->WTier[W0];
		const FString Title = FString(TEXT("FORGE: ")) + FString(WD.Name).ToUpper();
		if (T < 4)
			ShopRow(X, Y, W, Title, FString::Printf(TEXT("Tier %d"), T + 1), FString::Printf(TEXT("%s -> %s (%d dmg)"), WD.Names[T], WD.Names[T + 1], (int32)WD.Dmg[T + 1]),
				FString::Printf(TEXT("FORGE  %d"), WD.Cost[T + 1]), G->Souls >= WD.Cost[T + 1], TEXT("tier"));
		else ShopRow(X, Y, W, Title, TEXT("MAX"), WD.Names[T], TEXT("MAXED"), false, TEXT("none"));
		for (int32 i = 0; i < 7; i++) if (i != 6) StatRow(i);
		break;
	}
	case 1:
		for (int32 Slot = 0; Slot < 2; Slot++)
		{
			const FDSSkillDef& D = DSData::Skill(G->Equipped, Slot);
			const FDSSkillState& St = G->Skills[W0][Slot];
			const FString Title = FString::Printf(TEXT("%s (%s)"), D.Name, WD.Name);
			const FString Id = FString::Printf(TEXT("skill:%d"), Slot);
			if (!St.bUnlocked) ShopRow(X, Y, W, Title, TEXT("LOCKED"), D.Desc, FString::Printf(TEXT("UNLOCK  %d"), D.Unlock), G->Souls >= D.Unlock, Id);
			else if (St.Level < DSData::MaxSkillLv)
			{
				const int32 Cost = (int32)(D.LvlCost * (1.f + 0.6f * St.Level));
				ShopRow(X, Y, W, Title, FString::Printf(TEXT("Lv %d/%d"), St.Level + 1, DSData::MaxSkillLv + 1), D.Desc, FString::Printf(TEXT("UPGRADE  %d"), Cost), G->Souls >= Cost, Id);
			}
			else ShopRow(X, Y, W, Title, TEXT("MAX"), D.Desc, TEXT("MAXED"), false, TEXT("none"));
		}
		break;
	case 2:
		ShopRow(X, Y, W, TEXT("HEALING POTION"), FString::Printf(TEXT("x%d"), G->Flasks), TEXT("Restores health"), FString::Printf(TEXT("BUY  %d"), DSData::PotionCost),
			G->Souls >= DSData::PotionCost && G->Flasks < DSData::MaxPotions, TEXT("potion"));
		if (G->WeaponsOwned[3])
			ShopRow(X, Y, W, TEXT("REVOLVER AMMO"), FString::Printf(TEXT("x%d"), G->Ammo), FString::Printf(TEXT("A pack of %d bullets"), DSData::AmmoPack), FString::Printf(TEXT("BUY  %d"), DSData::AmmoCost),
				G->Souls >= DSData::AmmoCost && G->Ammo < DSData::MaxAmmo, TEXT("ammo"));
		else ShopRow(X, Y, W, TEXT("REVOLVER AMMO"), TEXT("LOCKED"), TEXT("Win the revolver (quest 27)."), TEXT("???"), false, TEXT("none"));
		StatRow(6);
		break;
	default:
		for (int32 i = 0; i < 4; i++)
		{
			const FDSWeaponDef& D = DSData::Weapon((EDSWeapon)i);
			if (G->WeaponsOwned[i])
			{
				const bool bEq = W0 == i;
				ShopRow(X, Y, W, FString(D.Names[G->WTier[i]]).ToUpper(), FString::Printf(TEXT("Tier %d"), G->WTier[i] + 1), FString::Printf(TEXT("%d damage"), (int32)D.Dmg[G->WTier[i]]),
					bEq ? TEXT("EQUIPPED") : TEXT("EQUIP"), !bEq, FString::Printf(TEXT("eqw:%d"), i));
			}
			else ShopRow(X, Y, W, FString(D.Name).ToUpper(), TEXT("LOCKED"), TEXT("Found or won in the world."), TEXT("???"), false, TEXT("none"));
		}
		for (int32 i = 0; i < 4; i++)
		{
			const FDSArmorDef& A = DSData::Armor((EDSArmor)i);
			if (G->ArmorsOwned[i])
			{
				const bool bEq = (int32)G->Armor == i;
				ShopRow(X, Y, W, FString(A.Name).ToUpper(), TEXT("ARMOR"), A.Desc, bEq ? TEXT("WORN") : TEXT("WEAR"), !bEq, FString::Printf(TEXT("eqa:%d"), i));
			}
			else ShopRow(X, Y, W, FString(A.Name).ToUpper(), TEXT("LOCKED"), TEXT("Dropped by a boss."), TEXT("???"), false, TEXT("none"));
		}
		break;
	}
	Button(TEXT("continue"), TEXT("CONTINUE THE QUEST"), VW * 0.5f, VH - 44.f * S, 360.f * S, 52.f * S);
}

// ------------------------------------------------------------------ pause / end

void ADSHUD::DrawPause()
{
	DrawRect(FLinearColor(0, 0, 0, 0.6f), 0, 0, VW, VH);
	Txt(TEXT("PAUSED"), VW * 0.5f, VH * 0.25f, 3.f * S, FLinearColor(0.85f, 0.7f, 0.35f), 1);
	Button(TEXT("resume"), TEXT("RESUME"), VW * 0.5f, VH * 0.5f - 60.f * S, 300.f * S, 58.f * S);
	Txt(FString::Printf(TEXT("MUSIC  %d%%"), (int32)(G->MusicVol * 100.f + 0.5f)), VW * 0.5f - 60.f * S, VH * 0.5f + 8.f * S, 1.0f * S, Bone, 2);
	Button(TEXT("mus-"), TEXT("-"), VW * 0.5f + 20.f * S, VH * 0.5f + 20.f * S, 50.f * S, 44.f * S);
	Button(TEXT("mus+"), TEXT("+"), VW * 0.5f + 80.f * S, VH * 0.5f + 20.f * S, 50.f * S, 44.f * S);
	Txt(FString::Printf(TEXT("EFFECTS  %d%%"), (int32)(G->SfxVol * 100.f + 0.5f)), VW * 0.5f - 60.f * S, VH * 0.5f + 62.f * S, 1.0f * S, Bone, 2);
	Button(TEXT("sfx-"), TEXT("-"), VW * 0.5f + 20.f * S, VH * 0.5f + 74.f * S, 50.f * S, 44.f * S);
	Button(TEXT("sfx+"), TEXT("+"), VW * 0.5f + 80.f * S, VH * 0.5f + 74.f * S, 50.f * S, 44.f * S);
	Button(TEXT("title"), TEXT("QUIT TO TITLE"), VW * 0.5f, VH * 0.5f + 160.f * S, 300.f * S, 58.f * S);
}

void ADSHUD::DrawEnd()
{
	const float A = FMath::Clamp(G->EndTimer / 1.2f, 0.f, 1.f);
	const bool bWin = G->State == EDSState::Win;
	DrawRect(bWin ? FLinearColor(0, 0, 0, 0.45f * A) : FLinearColor(0.12f, 0, 0, 0.6f * A), 0, 0, VW, VH);
	DrawRect(FLinearColor(0, 0, 0, 0.6f * A), 0, VH * 0.5f - 80.f * S, VW, 160.f * S);
	Txt(bWin ? TEXT("PRINCESS RESCUED") : TEXT("YOU DIED"), VW * 0.5f, VH * 0.5f - 50.f * S, (bWin ? 4.f : 5.5f) * S,
		bWin ? FLinearColor(0.85f, 0.7f, 0.35f, A) : FLinearColor(0.6f, 0.11f, 0.08f, A), 1);
	if (G->EndTimer > 2.2f)
	{
		Txt(bWin ? FString(TEXT("THE KINGDOM OF ELDORIA IS SAVED")) : FString::Printf(TEXT("SOULS LOST: %d"), G->LostSouls), VW * 0.5f, VH * 0.5f + 100.f * S, 1.0f * S, Bone, 1);
		Txt(bWin ? TEXT("TAP TO CONTINUE") : TEXT("TAP TO TRY AGAIN"), VW * 0.5f, VH * 0.5f + 130.f * S, 0.9f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.5f + 0.35f * FMath::Sin(G->Time * 3.f)), 1);
	}
}

// ------------------------------------------------------------------ text wrapping

float ADSHUD::Wrap(const FString& Text, float X, float Y, float W, float Scale, const FLinearColor& C)
{
	TArray<FString> Words;
	Text.ParseIntoArray(Words, TEXT(" "));
	float Cx = X, Cy = Y, LineH = 0.f;
	for (const FString& Word : Words)
	{
		float Tw = 0.f, Th = 0.f;
		GetTextSize(Word + TEXT(" "), Tw, Th, Font, Scale);
		LineH = Th;
		if (Cx + Tw > X + W && Cx > X) { Cx = X; Cy += Th + 2.f * S; }
		Txt(Word, Cx, Cy, Scale, C);
		Cx += Tw;
	}
	return Cy + LineH + 4.f * S;
}

// ------------------------------------------------------------------ minimap and world map

void ADSHUD::DrawMinimap()
{
	if (!G->bMapReady || !G->MapTex) return;
	const float Sz = 150.f * S, X = 24.f * S, Y = 150.f * S;
	const float Span = 110.f;                                          // metres across the minimap
	const float Tw = G->MapW * ADSGame::MapStep, Th = G->MapH * ADSGame::MapStep;
	const float U = (G->PPos.X - G->MapOrigin.X - Span * 0.5f) / Tw, V = (G->PPos.Y - G->MapOrigin.Y - Span * 0.5f) / Th;
	Box(X, Y, Sz, Sz, FLinearColor(0, 0, 0, 0.7f), Gold);
	DrawTexture(G->MapTex, X, Y, Sz, Sz, U, V, Span / Tw, Span / Th);
	// objective marker, clamped to the frame
	if (!G->bQDone && !G->Q.Title.IsEmpty())
	{
		FVector2D Off = (G->Site - G->PPos) / Span * Sz;
		const float Lim = Sz * 0.5f - 5.f * S;
		const float Mx = FMath::Max(FMath::Abs(Off.X), FMath::Abs(Off.Y));
		if (Mx > Lim) Off *= Lim / Mx;
		Box(X + Sz * 0.5f + Off.X - 4.f * S, Y + Sz * 0.5f + Off.Y - 4.f * S, 8.f * S, 8.f * S, Ember);
	}
	Box(X + Sz * 0.5f - 3.f * S, Y + Sz * 0.5f - 3.f * S, 6.f * S, 6.f * S, FLinearColor::White);
	G->AddButton(TEXT("minimap"), FBox2D(FVector2D(X, Y), FVector2D(X + Sz, Y + Sz)));
}

void ADSHUD::DrawMap()
{
	DrawRect(FLinearColor(0.01f, 0.012f, 0.02f, 0.97f), 0, 0, VW, VH);
	const float Sc = G->MapScale;
	auto ToScreen = [&](const FVector2D& P) { return FVector2D(VW * 0.5f + (P.X - G->MapCentre.X) * Sc, VH * 0.5f + (P.Y - G->MapCentre.Y) * Sc); };
	if (G->MapTex)
	{
		const FVector2D Tl = ToScreen(G->MapOrigin);
		DrawTexture(G->MapTex, Tl.X, Tl.Y, G->MapW * ADSGame::MapStep * Sc, G->MapH * ADSGame::MapStep * Sc, 0.f, 0.f, 1.f, 1.f);
	}
	const int32 Done = DSData::SiteIndex(FMath::Max(G->QuestN - 1, 1));
	for (int32 i = 0; i < DSData::RouteNum() - 1; i++)
	{
		const FVector2D A = ToScreen(DSData::Route(i)), B = ToScreen(DSData::Route(i + 1));
		DrawLine(A.X, A.Y, B.X, B.Y, i < Done ? FLinearColor(0.9f, 0.8f, 0.5f) : FLinearColor(0.85f, 0.81f, 0.72f, 0.55f), FMath::Max(2.f, 3.f * S));
	}
	for (int32 q = 1; q <= DSData::MaxQuest; q++)
	{
		const FVector2D P = ToScreen(DSData::Site(q));
		const bool bBoss = q % 10 == 0, bCur = q == G->QuestN;
		const float Sz = (bBoss ? 14.f : 9.f) * S * (bCur ? 1.4f : 1.f);
		Box(P.X - Sz * 0.5f, P.Y - Sz * 0.5f, Sz, Sz, bCur ? Ember : (q < G->QuestN ? FLinearColor(0.9f, 0.8f, 0.5f) : (bBoss ? FLinearColor(0.7f, 0.15f, 0.12f) : FLinearColor(0.45f, 0.45f, 0.5f))));
	}
	const FVector2D H = ToScreen(G->PPos);
	Box(H.X - 6.f * S, H.Y - 6.f * S, 12.f * S, 12.f * S, FLinearColor::White, Ember);
	Txt(FString::Printf(TEXT("QUEST %d - %s   (%d m)"), G->QuestN, *G->Q.Title.ToUpper(), (int32)FVector2D::Distance(G->PPos, G->Site)), VW * 0.5f, 18.f * S, 1.2f * S, Bone, 1);
	Txt(TEXT("drag to look around"), VW * 0.5f, VH - 34.f * S, 0.8f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.6f), 1);
	Button(TEXT("mapclose"), TEXT("X"), VW - 50.f * S, 50.f * S, 56.f * S, 56.f * S);
	Button(TEXT("mapzoomin"), TEXT("+"), VW - 50.f * S, 130.f * S, 56.f * S, 56.f * S);
	Button(TEXT("mapzoomout"), TEXT("-"), VW - 50.f * S, 200.f * S, 56.f * S, 56.f * S);
	Button(TEXT("maprecentre"), TEXT("O"), VW - 50.f * S, 270.f * S, 56.f * S, 56.f * S);
}

// ------------------------------------------------------------------ boss speech bubbles, civilians

void ADSHUD::DrawSpeeches()
{
	for (const ADSGame::FDSSpeech& Sp : G->Speeches)
	{
		FDSEnemyPtr E = Sp.Who.Pin();
		if (!E.IsValid()) continue;
		FVector2D Sc;
		const float H = E->Type == EDSEnemy::Cyborg ? 12.f : (E->Type == EDSEnemy::Serpent ? 5.5f : 4.5f);
		if (!G->WorldToScreen(G->P3(E->Pos, H), Sc)) continue;
		const float A = FMath::Clamp((Sp.Life - Sp.T) / 0.5f, 0.f, 1.f) * FMath::Clamp(Sp.T / 0.15f, 0.f, 1.f);
		const float W = 280.f * S;
		float Tw = 0.f, Th = 0.f;
		const int32 Chars = Sp.Text.Len();
		const float Lines = FMath::CeilToFloat(Chars * 9.5f * S / W) + 0.2f;
		const float Hh = Lines * 22.f * S + 14.f * S;
		const float X = Sc.X - W * 0.5f, Y = Sc.Y - Hh - 14.f * S;
		(void)Tw; (void)Th;
		Box(X, Y, W, Hh, FLinearColor(0.04f, 0.03f, 0.03f, 0.85f * A), FLinearColor(Sp.Col.R, Sp.Col.G, Sp.Col.B, A));
		DrawRect(FLinearColor(Sp.Col.R, Sp.Col.G, Sp.Col.B, A), Sc.X - 5.f * S, Y + Hh, 10.f * S, 10.f * S);
		const int32 Shown = FMath::Min(Chars, (int32)(Sp.T * 45.f));
		Wrap(Sp.Text.Left(Shown), X + 10.f * S, Y + 7.f * S, W - 20.f * S, 0.85f * S, FLinearColor(Sp.Col.R, Sp.Col.G, Sp.Col.B, A));
	}
}

void ADSHUD::DrawCivBars()
{
	for (const ADSGame::FDSCivilian& C : G->Civs)
	{
		if (C.State != 0 && C.State != 1 && C.State != 2) continue;
		FVector2D Sc;
		if (!G->WorldToScreen(G->P3(C.Pos, 2.5f), Sc)) continue;
		const float W = 46.f * S, Frac = FMath::Clamp(C.Hp / 80.f, 0.f, 1.f);
		const FLinearColor Col = Frac > 0.45f ? FLinearColor(0.56f, 0.88f, 1.f) : FLinearColor(1.f, 0.48f, 0.35f);
		DrawRect(FLinearColor(0, 0, 0, 0.7f), Sc.X - W * 0.5f - 1.f, Sc.Y - 1.f, W + 2.f, 7.f * S);
		DrawRect(Col, Sc.X - W * 0.5f, Sc.Y, W * Frac, 5.f * S);
		if (C.State != 0) Txt(C.State == 2 ? TEXT("STAY") : TEXT("FOLLOW"), Sc.X, Sc.Y - 18.f * S, 0.6f * S, Col, 1);
	}
}

// ------------------------------------------------------------------ comic epilogue and credits

namespace
{
	struct FSceneLook { FLinearColor Sky, Ground, Accent; int32 Figures; };   // Figures: 0 none, 1 knight, 2 knight + princess, 3 close-up face

	FSceneLook LookOf(const FString& Scene)
	{
		if (Scene == TEXT("fall")) return { FLinearColor(0.1f, 0.1f, 0.2f), FLinearColor(0.04f, 0.03f, 0.04f), FLinearColor(1.f, 0.5f, 0.2f), 0 };
		if (Scene == TEXT("kneel")) return { FLinearColor(0.15f, 0.12f, 0.2f), FLinearColor(0.07f, 0.06f, 0.06f), FLinearColor(0.8f, 0.4f, 0.2f), 1 };
		if (Scene == TEXT("face")) return { FLinearColor(0.28f, 0.2f, 0.24f), FLinearColor(0.12f, 0.08f, 0.09f), FLinearColor(1.f, 0.8f, 0.7f), 3 };
		if (Scene == TEXT("two")) return { FLinearColor(0.2f, 0.18f, 0.28f), FLinearColor(0.08f, 0.07f, 0.09f), FLinearColor(1.f, 0.7f, 0.4f), 2 };
		if (Scene == TEXT("crown")) return { FLinearColor(0.3f, 0.1f, 0.1f), FLinearColor(0.1f, 0.04f, 0.04f), FLinearColor(1.f, 0.8f, 0.2f), 1 };
		if (Scene == TEXT("cycle")) return { FLinearColor(0.12f, 0.2f, 0.32f), FLinearColor(0.05f, 0.08f, 0.12f), FLinearColor(0.5f, 0.8f, 1.f), 0 };
		if (Scene == TEXT("look")) return { FLinearColor(0.22f, 0.15f, 0.1f), FLinearColor(0.09f, 0.06f, 0.05f), FLinearColor(1.f, 0.6f, 0.3f), 1 };
		if (Scene == TEXT("vow")) return { FLinearColor(0.38f, 0.26f, 0.15f), FLinearColor(0.12f, 0.09f, 0.07f), FLinearColor(1.f, 0.85f, 0.5f), 2 };
		if (Scene == TEXT("walk")) return { FLinearColor(0.5f, 0.58f, 0.72f), FLinearColor(0.14f, 0.25f, 0.14f), FLinearColor(1.f, 0.95f, 0.8f), 2 };
		if (Scene == TEXT("gate")) return { FLinearColor(0.72f, 0.62f, 0.42f), FLinearColor(0.3f, 0.26f, 0.2f), FLinearColor(1.f, 0.9f, 0.5f), 0 };
		if (Scene == TEXT("coronation")) return { FLinearColor(0.82f, 0.72f, 0.42f), FLinearColor(0.35f, 0.28f, 0.2f), FLinearColor(1.f, 0.85f, 0.3f), 1 };
		return { FLinearColor(0.02f, 0.02f, 0.03f), FLinearColor(0.01f, 0.01f, 0.01f), FLinearColor(1.f, 0.45f, 0.1f), 0 };   // ember
	}
}

void ADSHUD::DrawComic()
{
	if (G->bCredits) { DrawCredits(); return; }
	DrawRect(FLinearColor(0.94f, 0.9f, 0.8f), 0, 0, VW, VH);
	const FDSComicPage Page = DSData::ComicPage(G->ComicPage);
	const float M = 26.f * S, Top = M + (FCString::Strlen(Page.Title) > 0 ? 38.f * S : 0.f);
	if (FCString::Strlen(Page.Title) > 0)
		Txt(FString::Printf(TEXT("%s  -  %s"), Page.Num, Page.Title), VW * 0.5f, M * 0.7f, 1.2f * S, FLinearColor(0.07f, 0.055f, 0.08f), 1);
	const float Px = M, Py = Top, Pw = VW - 2.f * M, Ph = VH - Top - M;
	for (int32 i = 0; i < Page.Panels.Num() && i < G->ComicShown; i++)
	{
		const FDSComicPanel& P = Page.Panels[i];
		const float X = Px + P.X * Pw + 3.f * S, Y = Py + P.Y * Ph + 3.f * S, W = P.W * Pw - 6.f * S, H = P.H * Ph - 6.f * S;
		const FSceneLook L = LookOf(P.Scene);
		Box(X, Y, W, H, L.Sky, FLinearColor(0.07f, 0.055f, 0.08f));
		DrawRect(L.Ground, X, Y + H * 0.72f, W, H * 0.28f);
		DrawRect(FLinearColor(L.Accent.R, L.Accent.G, L.Accent.B, 0.35f), X + W * 0.7f, Y + H * 0.1f, W * 0.12f, H * 0.18f);   // a moon / sun / fire glow
		if (L.Figures >= 1)
		{
			const float Fx = X + W * (L.Figures == 2 ? 0.34f : 0.5f), Fh = H * (L.Figures == 3 ? 0.6f : 0.42f), Fw = Fh * 0.38f;
			DrawRect(FLinearColor(0.2f, 0.21f, 0.25f), Fx - Fw * 0.5f, Y + H * 0.72f - Fh, Fw, Fh);                             // the knight
			DrawRect(FLinearColor(0.3f, 0.3f, 0.34f), Fx - Fw * 0.32f, Y + H * 0.72f - Fh - Fw * 0.5f, Fw * 0.64f, Fw * 0.55f);
			if (L.Figures >= 2)
			{
				const float Gx = X + W * 0.62f;
				DrawRect(FLinearColor(0.55f, 0.3f, 0.5f), Gx - Fw * 0.4f, Y + H * 0.72f - Fh * 0.9f, Fw * 0.8f, Fh * 0.9f);        // the princess
				DrawRect(FLinearColor(0.85f, 0.7f, 0.6f), Gx - Fw * 0.25f, Y + H * 0.72f - Fh * 0.9f - Fw * 0.5f, Fw * 0.5f, Fw * 0.5f);
			}
		}
		if (FCString::Strlen(P.Sfx) > 0) Txt(P.Sfx, X + W * 0.72f, Y + H * 0.3f, 2.2f * S, FLinearColor(1.f, 0.82f, 0.23f), 1);
		if (FCString::Strlen(P.Bubble) > 0)
		{
			const float Bw = FMath::Min(W * 0.8f, 340.f * S);
			const float Bx = X + (W - Bw) * 0.5f, By = Y + 10.f * S;
			const float Ey = Wrap(P.Bubble, Bx + 10.f * S, By + 8.f * S, Bw - 20.f * S, 0.85f * S, FLinearColor(0.07f, 0.055f, 0.08f));
			// the bubble is drawn behind its text: draw the box first by re-measuring
			DrawRect(FLinearColor(0.07f, 0.055f, 0.08f), Bx - 2.f, By - 2.f, Bw + 4.f, Ey - By + 2.f);
			DrawRect(FLinearColor(0.98f, 0.97f, 0.92f), Bx, By, Bw, Ey - By - 2.f);
			Wrap(P.Bubble, Bx + 10.f * S, By + 8.f * S, Bw - 20.f * S, 0.85f * S, FLinearColor(0.07f, 0.055f, 0.08f));
		}
		if (FCString::Strlen(P.Cap) > 0)
		{
			const float Cw = FMath::Min(W * 0.9f, 380.f * S);
			float Cy = Y + H - 70.f * S;
			DrawRect(FLinearColor(0.96f, 0.85f, 0.52f), X + 8.f * S, Cy, Cw, 62.f * S);
			Wrap(P.Cap, X + 16.f * S, Cy + 6.f * S, Cw - 16.f * S, 0.78f * S, FLinearColor(0.07f, 0.055f, 0.08f));
			if (FCString::Strlen(P.Cap2) > 0)
			{
				Cy -= 34.f * S;
				DrawRect(FLinearColor(0.96f, 0.85f, 0.52f), X + W - 160.f * S, Cy, 150.f * S, 28.f * S);
				Txt(P.Cap2, X + W - 150.f * S, Cy + 5.f * S, 0.9f * S, FLinearColor(0.07f, 0.055f, 0.08f));
			}
		}
	}
	Txt(G->ComicShown >= Page.Panels.Num() ? TEXT("TAP FOR THE NEXT PAGE") : TEXT("TAP"), VW - M, VH - 22.f * S, 0.8f * S, FLinearColor(0.3f, 0.25f, 0.2f, 0.6f + 0.3f * FMath::Sin(G->Time * 3.f)), 2);
}

void ADSHUD::DrawCredits()
{
	DrawRect(FLinearColor(0.01f, 0.01f, 0.015f), 0, 0, VW, VH);
	float Y = VH - G->CreditsT * 55.f * S;
	for (const FDSCreditLine& L : DSData::Credits())
	{
		Txt(L.Text, VW * 0.5f, Y, (L.Size / 16.f) * S * (L.bBold ? 1.1f : 0.9f), L.bBold ? FLinearColor(0.85f, 0.7f, 0.35f) : Bone, 1);
		Y += (L.Size + 14.f) * S;
	}
	if (G->CreditsT > 2.f) Txt(TEXT("tap to return"), VW * 0.5f, VH - 30.f * S, 0.8f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.4f + 0.3f * FMath::Sin(G->Time * 3.f)), 1);
}
