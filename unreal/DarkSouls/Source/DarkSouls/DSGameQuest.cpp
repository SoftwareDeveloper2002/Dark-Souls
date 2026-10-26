// Quest flow, camps, wayside encounters, shop, dialogue and save/load. Port of the campaign half of game.gd, quests.gd, shop.gd, save.gd.
#include "DSGame.h"
#include "DSVisual.h"
#include "DSSaveGame.h"
#include "Engine/PointLight.h"
#include "Components/StaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Components/AudioComponent.h"

// ================================================================== new game / continue

bool ADSGame::HasSave() const
{
	return UGameplayStatics::DoesSaveGameExist(UDSSaveGame::SlotName, 0);
}

void ADSGame::EnterGame()
{
	Music(TEXT("game"));
	State = EDSState::Play;
	bPaused = false;
	bShopOpen = false;
	bDialogActive = false;
	PAct = EDSAct::Idle;
	PStun = PStone = PInv = 0.f;
	PComboWin = 0.f;
	PCombo = -1;
	Recalc();
	PHp = PMaxHp;
	PSt = PMaxSt;
	HpTrail = PHp;
	ChapterShown = -1;
}

void ADSGame::StartNewGame()
{
	UGameplayStatics::DeleteGameInSlot(UDSSaveGame::SlotName, 0);
	for (int32& L : Lv) L = 0;
	for (int32 W = 0; W < 4; W++)
	{
		WeaponsOwned[W] = W == 0;
		WTier[W] = 0;
		ArmorsOwned[W] = W == 0;
		for (int32 S = 0; S < 2; S++) { Skills[W][S] = FDSSkillState(); Cds[W][S] = 0.f; }
	}
	Equipped = EDSWeapon::Sword;
	Armor = EDSArmor::Ashen;
	Souls = LostSouls = Keys = Ammo = 0;
	Flasks = 3;
	bUnlimitedAmmo = false;
	EmblemsFound.Reset();
	bHasWeapon = false;
	QuestN = 1;
	EnterGame();
	PPos = DSData::StartPos();
	CamFocus = P3(PPos);
	// the first sword lies on the road
	SwordPos = DSData::SwordSpot();
	bSwordOnGround = true;
	ADSVisual* S = GetWorld()->SpawnActor<ADSVisual>(P3(SwordPos, 0.6f), FRotator::ZeroRotator);
	S->AddPart(EDSShape::Cube, FVector::ZeroVector, FVector(0.12, 0.12, 1.4), FLinearColor(0.85f, 0.88f, 1.f) * 2.f);
	S->AddPart(EDSShape::Cube, FVector(0, 0, -0.55), FVector(0.5, 0.1, 0.1), FLinearColor(0.6f, 0.45f, 0.2f));
	S->SetShadows(false);
	SwordPickup = S;
	BeginQuest(1, false, false);
	Say(DSData::Intro(), [this]() { ShowBanner(TEXT("FIND YOUR SWORD"), 3.f, TEXT("Follow the road north")); });
}

void ADSGame::ContinueGame()
{
	UDSSaveGame* D = Cast<UDSSaveGame>(UGameplayStatics::LoadGameFromSlot(UDSSaveGame::SlotName, 0));
	if (!D) { StartNewGame(); return; }
	QuestN = FMath::Clamp(D->Quest, 1, DSData::MaxQuest);
	Souls = D->Souls;
	for (int32 i = 0; i < 7; i++) Lv[i] = D->Lv.IsValidIndex(i) ? D->Lv[i] : 0;
	for (int32 W = 0; W < 4; W++)
	{
		WeaponsOwned[W] = D->WeaponsOwned.IsValidIndex(W) ? D->WeaponsOwned[W] != 0 : W == 0;
		WTier[W] = D->WTier.IsValidIndex(W) ? FMath::Clamp(D->WTier[W], 0, 4) : 0;
		ArmorsOwned[W] = D->ArmorsOwned.IsValidIndex(W) ? D->ArmorsOwned[W] != 0 : W == 0;
		for (int32 S = 0; S < 2; S++)
		{
			const int32 I = W * 2 + S;
			Skills[W][S].bUnlocked = D->SkillUnlocked.IsValidIndex(I) && D->SkillUnlocked[I] != 0;
			Skills[W][S].Level = D->SkillLevel.IsValidIndex(I) ? FMath::Clamp(D->SkillLevel[I], 0, 5) : 0;
			Cds[W][S] = 0.f;
		}
	}
	Equipped = (EDSWeapon)FMath::Clamp(D->Equipped, 0, 3);
	if (!WeaponsOwned[(int32)Equipped]) Equipped = EDSWeapon::Sword;
	Armor = (EDSArmor)FMath::Clamp(D->Armor, 0, 3);
	if (!ArmorsOwned[(int32)Armor]) Armor = EDSArmor::Ashen;
	Ammo = D->Ammo;
	Flasks = D->Flasks;
	Keys = D->Keys;
	EmblemsFound = D->Emblems;
	bUnlimitedAmmo = D->bUnlimitedAmmo || EmblemsComplete();
	bHasWeapon = true;
	bSwordOnGround = false;
	EnterGame();
	PPos = DSData::Checkpoint(QuestN);
	CamFocus = P3(PPos);
	BeginQuest(QuestN, true, true);
}

void ADSGame::Save()
{
	UDSSaveGame* D = Cast<UDSSaveGame>(UGameplayStatics::CreateSaveGameObject(UDSSaveGame::StaticClass()));
	D->Quest = QuestN;
	D->Souls = Souls;
	D->Lv.Append(Lv, 7);
	for (int32 W = 0; W < 4; W++)
	{
		D->WeaponsOwned.Add(WeaponsOwned[W] ? 1 : 0);
		D->WTier.Add(WTier[W]);
		D->ArmorsOwned.Add(ArmorsOwned[W] ? 1 : 0);
		for (int32 S = 0; S < 2; S++)
		{
			D->SkillUnlocked.Add(Skills[W][S].bUnlocked ? 1 : 0);
			D->SkillLevel.Add(Skills[W][S].Level);
		}
	}
	D->Equipped = (int32)Equipped;
	D->Armor = (int32)Armor;
	D->Ammo = Ammo;
	D->Flasks = Flasks;
	D->Keys = Keys;
	D->bUnlimitedAmmo = bUnlimitedAmmo;
	D->Emblems = EmblemsFound;
	UGameplayStatics::SaveGameToSlot(D, UDSSaveGame::SlotName, 0);
}

void ADSGame::SaveNext()
{
	const int32 Cur = QuestN;
	QuestN = FMath::Min(Cur + 1, DSData::MaxQuest);
	Save();
	QuestN = Cur;
}

// ================================================================== dialogue / banners

void ADSGame::Say(TArrayView<const FDSLine> Lines, TFunction<void()> Done)
{
	DialogLines.Reset();
	for (const FDSLine& L : Lines) DialogLines.Add(L);
	DialogIdx = 0;
	DialogShown = 0.f;
	DialogDone = MoveTemp(Done);
	bDialogActive = DialogLines.Num() > 0;
	MoveInput = FVector2D::ZeroVector;
	if (!bDialogActive && DialogDone) { TFunction<void()> F = MoveTemp(DialogDone); DialogDone = nullptr; F(); }
}

void ADSGame::UpdateDialog(float Dt)
{
	if (bDialogActive) DialogShown += Dt * 45.f;
}

void ADSGame::TapScreen()
{
	if (State == EDSState::Comic) { ComicTap(); return; }
	if (bDialogActive)
	{
		const int32 Len = FCString::Strlen(DialogLines[DialogIdx].Text);
		if (DialogShown < Len) { DialogShown = (float)Len; return; }
		DialogIdx++;
		DialogShown = 0.f;
		if (DialogIdx >= DialogLines.Num())
		{
			bDialogActive = false;
			TFunction<void()> F = MoveTemp(DialogDone);
			DialogDone = nullptr;
			if (F) F();
		}
		return;
	}
	if ((State == EDSState::Dead || State == EDSState::Win) && EndTimer > 2.2f)
	{
		if (State == EDSState::Win) ComicStart();
		else Respawn();
	}
}

void ADSGame::OnButton(const FString& Id)
{
	if (Id == TEXT("new")) { StartNewGame(); return; }
	if (Id == TEXT("continue")) { ContinueGame(); return; }
	if (Id == TEXT("resume")) { bPaused = false; return; }
	if (Id == TEXT("pause")) { TogglePause(); return; }
	if (Id == TEXT("title"))
	{
		bPaused = false;
		ClearField();
		State = EDSState::Title;
		bHasSaveCached = HasSave();
		if (PlayerFig) PlayerFig->SetActorHiddenInGame(true);
		return;
	}
	if (Id == TEXT("swap")) { CycleWeapon(); return; }
	if (Id == TEXT("torch")) { TorchToggle(); return; }
	if (Id == TEXT("cmd")) { CivCommand(); return; }
	if (Id == TEXT("minimap") || Id == TEXT("mapclose")) { ToggleMap(); return; }
	if (Id == TEXT("mapzoomin")) { MapScale = FMath::Min(MapScale * 1.4f, 3.f); return; }
	if (Id == TEXT("mapzoomout")) { MapScale = FMath::Max(MapScale / 1.4f, 0.15f); return; }
	if (Id == TEXT("maprecentre")) { MapCentre = PPos; return; }
	if (Id == TEXT("mus-")) { MusicVol = FMath::Max(0.f, MusicVol - 0.2f); if (MusicComp) MusicComp->SetVolumeMultiplier(MusicVol); return; }
	if (Id == TEXT("mus+")) { MusicVol = FMath::Min(1.f, MusicVol + 0.2f); if (MusicComp) MusicComp->SetVolumeMultiplier(MusicVol); return; }
	if (Id == TEXT("sfx-")) { SfxVol = FMath::Max(0.f, SfxVol - 0.2f); return; }
	if (Id == TEXT("sfx+")) { SfxVol = FMath::Min(1.f, SfxVol + 0.2f); return; }
	if (bShopOpen) ShopBuy(Id);
}

// ================================================================== shop

void ADSGame::ShopBuy(const FString& Id)
{
	const int32 W = (int32)Equipped;
	if (Id.StartsWith(TEXT("tab:"))) { ShopTab = FCString::Atoi(*Id.Mid(4)); return; }
	if (Id == TEXT("continue")) { CloseShop(); return; }
	if (Id == TEXT("tier"))
	{
		const int32 T = WTier[W];
		if (T >= 4) return;
		const int32 Cost = DSData::Weapon(Equipped).Cost[T + 1];
		if (Souls < Cost) return;
		Souls -= Cost;
		WTier[W] = T + 1;
	}
	else if (Id.StartsWith(TEXT("stat:")))
	{
		const int32 I = FCString::Atoi(*Id.Mid(5));
		const FDSStatDef& S = DSData::Stats()[I];
		if (Lv[I] >= S.Max) return;
		const int32 Cost = StatCost(S.BaseCost, Lv[I]);
		if (Souls < Cost) return;
		Souls -= Cost;
		Lv[I]++;
		Recalc();
	}
	else if (Id.StartsWith(TEXT("skill:")))
	{
		const int32 Slot = FCString::Atoi(*Id.Mid(6, 1));
		const FDSSkillDef& D = DSData::Skill(Equipped, Slot);
		FDSSkillState& St = Skills[W][Slot];
		const bool bUnlock = !St.bUnlocked;
		const int32 Cost = bUnlock ? D.Unlock : (int32)(D.LvlCost * (1.f + 0.6f * St.Level));
		if (Souls < Cost || (!bUnlock && St.Level >= DSData::MaxSkillLv)) return;
		Souls -= Cost;
		if (bUnlock) St.bUnlocked = true; else St.Level++;
	}
	else if (Id == TEXT("potion"))
	{
		if (Souls < DSData::PotionCost || Flasks >= DSData::MaxPotions) return;
		Souls -= DSData::PotionCost;
		Flasks++;
	}
	else if (Id == TEXT("ammo"))
	{
		if (Souls < DSData::AmmoCost || Ammo >= DSData::MaxAmmo || !WeaponsOwned[(int32)EDSWeapon::Gun]) return;
		Souls -= DSData::AmmoCost;
		Ammo = FMath::Min(DSData::MaxAmmo, Ammo + DSData::AmmoPack);
	}
	else if (Id.StartsWith(TEXT("eqw:"))) EquipWeapon((EDSWeapon)FCString::Atoi(*Id.Mid(4)));
	else if (Id.StartsWith(TEXT("eqa:"))) EquipArmor((EDSArmor)FCString::Atoi(*Id.Mid(4)));
}

void ADSGame::OpenShop()
{
	MoveInput = FVector2D::ZeroVector;
	SaveNext();
	PHp = PMaxHp;
	PSt = PMaxSt;
	HpTrail = PHp;
	Flasks = FMath::Max(Flasks, 3);
	Burst(PPos, 20, FLinearColor(1.f, 0.7f, 0.28f), 8.f);
	bShopOpen = true;
	ShopTab = 0;
}

void ADSGame::CloseShop()
{
	bShopOpen = false;
	SaveNext();
	BeginQuest(FMath::Min(QuestN + 1, DSData::MaxQuest));
}

// ================================================================== quest start

void ADSGame::BeginQuest(int32 N, bool bIntro, bool bWithFire)
{
	MazeFailT = -1.f;
	QuestN = N;
	Q = DSData::MakeQuest(N);
	Site = DSData::Site(N);
	bQActive = bQArrived = bCampSpawned = bArenaActive = bQDone = false;
	QStage.Empty();
	QKills = 0;
	QTimer = 0.f;
	QCd = 0.8f;
	bQBossDead = bQEliteDead = false;
	AwayWarn = 0.f;
	ClearField();
	if (bWithFire)
	{
		FreeCamp();
		BuildBonfire(PPos + FVector2D(-3, 2));
	}
	ApplyChapter(Q.Ch);
	Music(TEXT("game"));
	FxIntensity = 1.f;
	// one-off structures are built on demand
	if (N == 27 && !Maze.bBuilt) BuildMaze(Site, DSData::DirAt(DSData::SiteIndex(27)));
	else if (N == 30 && !Bridge.bBuilt) BuildBridge(Site, DSData::DirAt(DSData::SiteIndex(30)));
	SetupWayside();
	if (bIntro && Q.Idx == 1)
	{
		const FDSChapter& C = DSData::Chapter(Q.Ch);
		ShowBanner(C.Name, 2.8f, C.Sub);
		Say(DSData::ChapterStart(Q.Ch), nullptr);
	}
	else
	{
		ShowBanner(FString::Printf(TEXT("QUEST %d"), QuestN), 2.2f, Q.Title.ToUpper());
	}
}

void ADSGame::FreeCamp()
{
	EmblemsCampFreed();
	for (TWeakObjectPtr<ADSVisual>& P : CampProps) if (P.IsValid()) P->Destroy();
	CampProps.Reset();
	for (TWeakObjectPtr<AActor>& L : CampLights) if (L.IsValid()) L->Destroy();
	CampLights.Reset();
}

void ADSGame::BuildBonfire(const FVector2D& At)
{
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(At), FRotator::ZeroRotator);
	V->AddPart(EDSShape::Cylinder, FVector(0, 0, 0.2), FVector(1.4, 1.4, 0.4), FLinearColor(0.25f, 0.23f, 0.2f));
	V->AddPart(EDSShape::Cube, FVector(0, 0, 0.6), FVector(0.15, 0.15, 1.1), FLinearColor(0.7f, 0.7f, 0.65f));    // the coiled sword
	V->AddPart(EDSShape::Cone, FVector(0, 0, 0.9), FVector(0.8, 0.8, 1.4), FLinearColor(1.f, 0.5f, 0.1f) * 3.f);   // flame
	V->AttachModel(TEXT("Props"), TEXT("stone_fire_pit"), 0.5f, { 0 });
	V->SetShadows(false);
	CampProps.Add(V);
	if (APointLight* L = GetWorld()->SpawnActor<APointLight>(P3(At, 1.5f), FRotator::ZeroRotator))
	{
		L->GetRootComponent()->SetMobility(EComponentMobility::Movable);
		L->GetLightComponent()->SetLightColor(FLinearColor(1.f, 0.55f, 0.2f));
		L->GetLightComponent()->SetIntensity(8000.f);
		DSSetLightRadius(L, 1500.f);
		CampLights.Add(L);
	}
}

void ADSGame::BuildCamp(const FVector2D& C, int32 Ch, bool bBoss)
{
	static const FLinearColor Faction[4] = { FLinearColor(0.54f, 0.11f, 0.08f), FLinearColor(0.16f, 0.42f, 0.29f), FLinearColor(0.42f, 0.54f, 0.75f), FLinearColor(0.35f, 0.04f, 0.08f) };
	const int32 Tents = bBoss ? 0 : 4;
	for (int32 i = 0; i < Tents; i++)
	{
		const float A = (float)i / Tents * 2.f * PI + 0.4f;
		const FVector2D P = C + FromAngle(A) * 10.f;
		ADSVisual* T = GetWorld()->SpawnActor<ADSVisual>(P3(P), FRotator(0, FMath::RadiansToDegrees(A) + 90.f, 0));
		T->AddPart(EDSShape::Cone, FVector(0, 0, 1.3), FVector(3.4, 3.4, 2.6), Faction[Ch]);
		T->AttachModel(TEXT("Props"), TEXT("medieval_tent"), 3.0f, { 0 });
		CampProps.Add(T);
	}
	CampTents.Reset();
	CampRocks.Reset();
	for (int32 i = 0; i < Tents; i++) CampTents.Add(C + FromAngle((float)i / Tents * 2.f * PI + 0.4f) * 10.f);
	for (int32 i = 0; i < 3 && !bBoss; i++)
	{
		const FVector2D Rp = C + FromAngle(i * 2.2f + 1.f) * 7.f;
		ADSVisual* Rk = GetWorld()->SpawnActor<ADSVisual>(P3(Rp), FRotator::ZeroRotator);
		Rk->AddPart(EDSShape::Sphere, FVector(0, 0, 0.5), FVector(1.6, 1.3, 1.1), FLinearColor(0.3f, 0.3f, 0.32f));
		static const TCHAR* RockNames[] = { TEXT("RockA"), TEXT("RockB"), TEXT("RockC") };
		Rk->AttachModel(TEXT("Props"), RockNames[i % 3], 1.5f, { 0 });
		CampProps.Add(Rk);
		CampRocks.Add(Rp);
	}
	// a ring of standing stones: the arena for boss fights
	if (bBoss)
	{
		for (int32 i = 0; i < 24; i++)
		{
			const float A = (float)i / 24.f * 2.f * PI;
			ADSVisual* S = GetWorld()->SpawnActor<ADSVisual>(P3(C + FromAngle(A) * ArenaR), FRotator::ZeroRotator);
			S->AddPart(EDSShape::Cube, FVector(0, 0, 2.0), FVector(1.5, 1.5, 4.0 + (i % 3)), FLinearColor(0.26f, 0.27f, 0.3f));
			static const TCHAR* StoneNames[] = { TEXT("RockA"), TEXT("RockB"), TEXT("RockC") };
			S->AttachModel(TEXT("Props"), StoneNames[i % 3], 4.5f + (i % 3), { 0 });
			CampProps.Add(S);
		}
	}
	BuildBonfire(C + FVector2D(0, 3));
	EmblemsCampBuilt(QuestN, C);
}

void ADSGame::SpawnCamp()
{
	if (Q.Kind == EDSQuestKind::Maze && !Maze.bBuilt) return;
	bCampSpawned = true;
	if (Q.Kind != EDSQuestKind::Maze && QuestN != 30)
	{
		FreeCamp();
		BuildCamp(Site, Q.Ch, Q.Kind == EDSQuestKind::Boss);
	}
	switch (Q.Kind)
	{
	case EDSQuestKind::Kill:
		for (int32 i = 0, N = FMath::Min(Q.Target, 4 + Q.Ch); i < N; i++)
		{
			const FVector2D P = SpawnNear(Site, 5.f, 16.f);
			SpawnEnemy(PickKind(), &P, true, true);
		}
		break;
	case EDSQuestKind::Elite:
	{
		const FVector2D Cp = Site + FVector2D(0, -4);
		SpawnEnemy(EDSEnemy::Captain, &Cp, true, true);
		for (int32 i = 0; i < 2; i++)
		{
			const FVector2D P = SpawnNear(Site, 5.f, 14.f);
			SpawnEnemy(PickKind(), &P, true, true);
		}
		break;
	}
	case EDSQuestKind::Maze:
	{
		CivSpawn(Maze.CivSpots);
		static const EDSEnemy MazeKinds[] = { EDSEnemy::Zombie, EDSEnemy::Ghoul, EDSEnemy::Hound, EDSEnemy::Skeleton, EDSEnemy::Ghoul, EDSEnemy::Fiend, EDSEnemy::Hound, EDSEnemy::Zombie, EDSEnemy::Skeleton, EDSEnemy::Ghoul, EDSEnemy::Hound, EDSEnemy::Fiend, EDSEnemy::Zombie };
		const TArray<FVector2D> Pts = MazeSpawnPoints(13, Maze.Entrance, Maze.CivSpots);
		for (int32 i = 0; i < Pts.Num(); i++)
		{
			FDSEnemyPtr E = SpawnEnemy(MazeKinds[i % UE_ARRAY_COUNT(MazeKinds)], &Pts[i], false, true);
			E->bWayside = true;
		}
		break;
	}
	case EDSQuestKind::Boss:
	{
		FVector2D Bp = Site + FVector2D(0, -8);
		if (QuestN == 30) Bp = Bridge.BossPos;
		SpawnEnemy(Q.Boss, &Bp, true, true);
		break;
	}
	default: break;   // survive: enemies stream in once you arrive
	}
}

void ADSGame::Arrive()
{
	bQArrived = bQActive = true;
	for (const FDSEnemyPtr& E : Enemies) if (E->bQuest) E->bForce = true;
	if (Q.Kind == EDSQuestKind::Boss)
	{
		if (QuestN == 30) bBridgeActive = true; else bArenaActive = true;
		Sfx(TEXT("roar"), -2.f, 0.8f + 0.1f * Q.Ch);
		Music(Q.Boss == EDSEnemy::Malakar ? TEXT("final") : TEXT("boss"));
		FxIntensity = 1.8f;
		Strike(Site + FVector2D(0, -8));
		Shake = 10.f;
		Say(DSData::BossIntro(QuestN), nullptr);
	}
	else if (Q.Kind == EDSQuestKind::Maze)
	{
		Say(DSData::MazeText(), nullptr);
	}
	ShowBanner(FString::Printf(TEXT("QUEST %d  -  %s"), QuestN, *Q.Title.ToUpper()), 2.4f);
}

// ================================================================== quest update

void ADSGame::QuestUpdate(float Dt)
{
	if (bQDone || Q.Title.IsEmpty()) return;
	const float Dist = FVector2D::Distance(PPos, Site);
	if (!bCampSpawned && Dist < CampRange) SpawnCamp();
	if (!bQArrived)
	{
		const float Ar = QuestN == 30 ? 34.f : ArriveRange;
		if (bCampSpawned && Q.Kind == EDSQuestKind::Maze) { if (MazeMargin(PPos) > 1.f) Arrive(); }
		else if (bCampSpawned && Dist < Ar) Arrive();
		return;
	}
	const int32 Alive = QuestEnemyCount();
	const int32 Cap = FMath::Min(Q.MaxAlive, 7);
	switch (Q.Kind)
	{
	case EDSQuestKind::Kill:
	{
		if (QKills >= Q.Target) { CompleteQuest(); return; }
		QCd -= Dt;
		if (QCd <= 0.f && Alive < Cap && Q.Target - QKills - Alive > 0)
		{
			QCd = Q.Interval;
			const FVector2D P = SpawnNear(Site, 18.f, 28.f);
			SpawnEnemy(PickKind(), &P, true, false);
		}
		break;
	}
	case EDSQuestKind::Survive:
	{
		if (Dist < 34.f) { QTimer += Dt; AwayWarn = 0.f; } else AwayWarn += Dt;
		if (QTimer >= Q.Target) { CleanupQuestEnemies(); CompleteQuest(); return; }
		QCd -= Dt;
		if (QCd <= 0.f && Alive < Cap)
		{
			QCd = Q.Interval;
			const FVector2D P = SpawnNear(Site, 18.f, 28.f);
			SpawnEnemy(PickKind(), &P, true, false);
		}
		break;
	}
	case EDSQuestKind::Elite:
	{
		if (bQEliteDead) { CleanupQuestEnemies(); CompleteQuest(); return; }
		QCd -= Dt;
		if (QCd <= 0.f && Alive < Cap + 1)
		{
			QCd = Q.Interval * 1.4f;
			const FVector2D P = SpawnNear(Site, 18.f, 28.f);
			SpawnEnemy(PickKind(), &P, true, false);
		}
		break;
	}
	case EDSQuestKind::Maze:
		if (CivAllSaved()) CompleteQuest();
		break;
	case EDSQuestKind::Boss:
	{
		bool bDying = false;
		for (const FDSCorpse& C : Corpses) if (C.bBoss) bDying = true;
		if (bQBossDead && !bDying) { CleanupQuestEnemies(); CompleteQuest(); }
		break;
	}
	default: break;
	}
}

void ADSGame::CleanupQuestEnemies()
{
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
		if (E->bQuest && !E->bDead) KillEnemy(E, false);
}

void ADSGame::CompleteQuest()
{
	bQDone = true;
	QDoneT = 0.f;
	bArenaActive = false;
	bBridgeActive = false;
	Sfx(TEXT("chime"), -4.f);
	if (Q.Kind == EDSQuestKind::Boss) Music(TEXT("game"));
	const int32 Reward = 40 + 12 * QuestN;
	Souls += Reward;
	ShowBanner(TEXT("QUEST COMPLETE"), 2.4f, FString::Printf(TEXT("+%d SOULS"), Reward));
	QStage = TEXT("wait");
}

void ADSGame::SpawnChest()
{
	ChestPos = Site + FVector2D(0, 8);
	ADSVisual* C = GetWorld()->SpawnActor<ADSVisual>(P3(ChestPos), FRotator::ZeroRotator);
	C->AddPart(EDSShape::Cube, FVector(0, 0, 0.35), FVector(1.3, 0.85, 0.7), FLinearColor(0.29f, 0.17f, 0.09f));
	C->AddPart(EDSShape::Cube, FVector(0, 0, 0.84), FVector(1.3, 0.85, 0.28), FLinearColor(0.85f, 0.69f, 0.31f));
	ChestActor = C;
	ChestT = 0.f;
	Burst(ChestPos, 20, FLinearColor(1.f, 0.84f, 0.44f), 8.f, 0.6f);
}

void ADSGame::PostQuest(float Dt)
{
	QDoneT += Dt;
	if (QStage == TEXT("wait"))
	{
		if (QDoneT > 2.f)
		{
			if (DSData::MaxQuest >= QuestN && QuestN % 10 == 0)
			{
				SpawnChest();
				QStage = TEXT("chest");
				QDoneT = 0.f;
			}
			else
			{
				QStage = TEXT("shop");
				OpenShop();
			}
		}
	}
	else if (QStage == TEXT("chest"))
	{
		ChestT += Dt;
		if (ChestActor.IsValid())
			if (UStaticMeshComponent* Lid = ChestActor->GetPart(1))
				Lid->SetRelativeRotation(FRotator(FMath::Clamp(ChestT / 0.8f, 0.f, 1.f) * 70.f, 0, 0));
		if (ChestT > 0.8f)
		{
			QStage = TEXT("chest_open");
			const FDSBossReward& Rw = DSData::BossReward(QuestN);
			Souls += Rw.Souls;
			Burst(ChestPos, 24, FLinearColor(1.f, 0.84f, 0.44f), 9.f, 1.4f);
			Float(P3(ChestPos, 2.4f), FString::Printf(TEXT("TREASURE +%d"), Rw.Souls), FLinearColor(1.f, 0.84f, 0.44f));
			TArray<FString> Gains;
			if (FCString::Strlen(Rw.Key) > 0) { Keys++; Gains.Add(FString(TEXT("THE ")) + Rw.Key); }
			if (Rw.Weapon >= 0)
			{
				WeaponsOwned[Rw.Weapon] = true;
				Gains.Add(FString(DSData::Weapon((EDSWeapon)Rw.Weapon).Name).ToUpper());
				EquipWeapon((EDSWeapon)Rw.Weapon);
			}
			if (Rw.Armor >= 0)
			{
				ArmorsOwned[Rw.Armor] = true;
				Gains.Add(FString(DSData::Armor((EDSArmor)Rw.Armor).Name).ToUpper());
				EquipArmor((EDSArmor)Rw.Armor);
			}
			if (Gains.Num() > 0) ShowBanner(TEXT("FOUND: ") + FString::Join(Gains, TEXT(", ")), 4.f, FString::Printf(TEXT("KEYS %d / 3"), Keys));
			QDoneT = 0.f;
		}
	}
	else if (QStage == TEXT("chest_open"))
	{
		if (QDoneT > 2.8f)
		{
			QStage = TEXT("story");
			if (QuestN == 40)
			{
				Say(DSData::BossDefeat(40), [this]()
				{
					State = EDSState::Win;
					EndTimer = 0.f;
				});
			}
			else
			{
				Say(DSData::BossDefeat(QuestN), [this]() { QStage = TEXT("shop"); OpenShop(); });
			}
		}
	}
}

// ================================================================== wayside groups

void ADSGame::SetupWayside()
{
	Wayside.Reset();
	const int32 I1 = DSData::SiteIndex(QuestN);
	const int32 I0 = QuestN == 1 ? DSData::StartIdx + 6 : DSData::SiteIndex(QuestN - 1);
	for (const FVector2D& Sp : DSData::Between(I0, I1, 3))
	{
		FDSWayside G;
		G.Pos = Sp + FromAngle(FMath::FRand() * 2.f * PI) * FMath::FRandRange(0.f, 5.f);
		const int32 Cnt = 2 + (QuestN > 18 ? 1 : 0) + (QuestN > 32 ? 1 : 0);
		for (int32 k = 0; k < Cnt; k++) G.Kinds.Add(PickKindFor(Q.Ch));
		Wayside.Add(G);
	}
}

void ADSGame::UpdateWayside()
{
	for (FDSWayside& G : Wayside)
	{
		if (G.bDone) continue;
		const float D = FVector2D::Distance(PPos, G.Pos);
		if (Q.Kind == EDSQuestKind::Boss && FVector2D::Distance(G.Pos, Site) < 52.f) { G.bDone = true; continue; }
		if (!G.bSpawned && D < 80.f)
		{
			G.bSpawned = true;
			G.Members.Reset();
			for (int32 k = 0; k < G.Kinds.Num(); k++)
			{
				const FVector2D P = G.Pos + FromAngle((float)k / G.Kinds.Num() * 2.f * PI) * 2.5f;
				FDSEnemyPtr E = SpawnEnemy(G.Kinds[k], &P, false, true);
				E->bWayside = true;
				G.Members.Add(E);
			}
		}
		else if (G.bSpawned)
		{
			int32 Alive = 0;
			bool bCalm = true;
			for (const TWeakPtr<FDSEnemy>& M : G.Members)
				if (FDSEnemyPtr E = M.Pin())
					if (!E->bDead) { Alive++; if (E->Mode != EDSMode::Idle) bCalm = false; }
			if (Alive == 0) G.bDone = true;
			else if (D > 170.f && bCalm)
			{
				for (const TWeakPtr<FDSEnemy>& M : G.Members) if (FDSEnemyPtr E = M.Pin()) RemoveEnemy(*E);
				G.bSpawned = false;
			}
		}
	}
}

// ================================================================== reset / death

void ADSGame::ClearField()
{
	CivClear();
	TorchLeave();
	Speeches.Reset();
	for (FDSEnemyPtr& E : Enemies) if (!E->bDead) RemoveEnemy(*E);
	Enemies.Reset();
	Wayside.Reset();
	for (FDSCorpse& C : Corpses) if (C.Fig.IsValid()) C.Fig->Destroy();
	Corpses.Reset();
	for (FDSProjectile& P : Projs) if (P.Node.IsValid()) P.Node->Destroy();
	Projs.Reset();
	for (FDSZone& Z : Zones) if (Z.Node.IsValid()) Z.Node->Destroy();
	Zones.Reset();
	if (ChestActor.IsValid()) ChestActor->Destroy();
	ChestT = -1.f;
	FreeCamp();
}

void ADSGame::Respawn()
{
	LostSouls = Souls / 4;
	Souls -= LostSouls;
	PPos = DSData::Checkpoint(QuestN);
	CamFocus = P3(PPos);
	PHp = PMaxHp;
	HpTrail = PHp;
	PSt = PMaxSt;
	PAct = EDSAct::Idle;
	PStun = PStone = 0.f;
	PInv = 1.f;
	Flasks = FMath::Max(Flasks, 3);
	State = EDSState::Play;
	BeginQuest(QuestN, false, true);
	ShowBanner(TEXT("YOU RETURN TO THE FIRE"), 2.2f, FString::Printf(TEXT("QUEST %d"), QuestN));
}

// ================================================================== HUD text

FString ADSGame::ControlLabel() const
{
	if (!bHasWeapon && bSwordOnGround && FVector2D::Distance(PPos, SwordPos) < 2.6f) return TEXT("TAKE");
	if (!bHasWeapon) return TEXT("---");
	if (ChestNear(PPos, 2.6f) >= 0) return TEXT("OPEN");
	if (Q.Kind == EDSQuestKind::Maze && CivNear(PPos, 2.8f) >= 0) return TEXT("RESCUE");
	if (bTorchHeld) return TEXT("NO WEAPON");
	if (!bExecActive && ExecFind().IsValid()) return TEXT("GRAB");
	return DSData::Weapon(Equipped).Style == EDSStyle::Shoot ? TEXT("SHOOT") : TEXT("ATTACK");
}

FString ADSGame::QuestLine() const
{
	switch (Q.Kind)
	{
	case EDSQuestKind::Kill: return bQArrived ? FString::Printf(TEXT("%s  %d / %d"), *Q.Text, QKills, Q.Target) : Q.Text;
	case EDSQuestKind::Survive: return bQArrived ? FString::Printf(TEXT("%s  %d s"), *Q.Text, FMath::Max(0, Q.Target - (int32)QTimer)) : Q.Text;
	default: return Q.Text;
	}
}
