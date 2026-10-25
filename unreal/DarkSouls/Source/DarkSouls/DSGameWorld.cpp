// World structures: collision walls, the cutaway tunnel, the treasure labyrinth with its torch and civilians, the boss bridge and the forest.
// Port of structures.gd, torch.gd, civilians.gd and forest.gd.
#include "DSGame.h"
#include "DSVisual.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/PointLight.h"
#include "Engine/World.h"
#include "Math/RandomStream.h"

namespace
{
	int64 CellKey(int32 X, int32 Y) { return ((int64)X << 32) ^ (int64)(uint32)Y; }
	const FLinearColor RockCol(0.22f, 0.22f, 0.24f);
	float YawOf(const FVector2D& D) { return FMath::Atan2(D.Y, D.X); }   // box yaw so that its long X side runs along D
}

// ================================================================== collision

void ADSGame::AddWall(const FVector2D& A, const FVector2D& B, float Thick)
{
	const int32 Idx = Walls.Add({ A, B, Thick * 0.5f });
	const FVector2D Lo = FVector2D(FMath::Min(A.X, B.X), FMath::Min(A.Y, B.Y)) - FVector2D(2.8, 2.8);
	const FVector2D Hi = FVector2D(FMath::Max(A.X, B.X), FMath::Max(A.Y, B.Y)) + FVector2D(2.8, 2.8);
	for (int32 Cx = FMath::FloorToInt(Lo.X / 8.0); Cx <= FMath::FloorToInt(Hi.X / 8.0); Cx++)
		for (int32 Cy = FMath::FloorToInt(Lo.Y / 8.0); Cy <= FMath::FloorToInt(Hi.Y / 8.0); Cy++)
			WallGrid.FindOrAdd(CellKey(Cx, Cy)).Add(Idx);
}

bool ADSGame::WallOnly(const FVector2D& P, float Rad) const
{
	const TArray<int32>* L = WallGrid.Find(CellKey(FMath::FloorToInt(P.X / 8.0), FMath::FloorToInt(P.Y / 8.0)));
	if (!L) return false;
	for (int32 I : *L)
	{
		const FDSWall& W = Walls[I];
		const FVector2D Ab = W.B - W.A;
		const float T = FMath::Clamp(FVector2D::DotProduct(P - W.A, Ab) / FMath::Max(Ab.SizeSquared(), 0.0001), 0.0, 1.0);
		const FVector2D Cp = W.A + Ab * T;
		const float Lim = Rad + W.R;
		if (FVector2D::DistSquared(P, Cp) < Lim * Lim) return true;
	}
	return false;
}

bool ADSGame::WallHit(const FVector2D& P, float Rad) const
{
	if (WallOnly(P, Rad)) return true;
	const int32 Cx = FMath::FloorToInt(P.X / 6.0), Cy = FMath::FloorToInt(P.Y / 6.0);
	for (int32 Dx = -1; Dx <= 1; Dx++)
		for (int32 Dy = -1; Dy <= 1; Dy++)
			if (const TArray<FVector>* T = Trunks.Find(CellKey(Cx + Dx, Cy + Dy)))
				for (const FVector& V : *T)
				{
					const float Lim = Rad + V.Z;
					if ((P.X - V.X) * (P.X - V.X) + (P.Y - V.Y) * (P.Y - V.Y) < Lim * Lim) return true;
				}
	return false;
}

namespace
{
	/** A burning torch/sconce: pole + flame. */
	ADSVisual* MakeTorchProp(UWorld* W, const FVector& PosCm, const FLinearColor& Flame)
	{
		ADSVisual* V = W->SpawnActor<ADSVisual>(PosCm, FRotator::ZeroRotator);
		V->AddPart(EDSShape::Cylinder, FVector(0, 0, 0.75), FVector(0.14, 0.14, 1.5), FLinearColor(0.16f, 0.11f, 0.06f));
		V->AddPart(EDSShape::Cone, FVector(0, 0, 1.75), FVector(0.3, 0.3, 0.55), Flame * 4.f);
		V->SetShadows(false);
		return V;
	}
}

// ================================================================== tunnel

void ADSGame::BuildTunnel()
{
	const int32 Start = DSData::SiteIndex(10) + 5;
	TunnelPts.Reset();
	for (int32 i = Start - 1; i <= Start + 11 + 1; i++) TunnelPts.Add(DSData::Route(i));
	UWorld* W = GetWorld();
	ADSVisual* Holder = W->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
	UInstancedStaticMeshComponent* Rock = Holder->AddInstanced(EDSShape::Cube, RockCol);
	const float WallH = 6.8f;
	for (int32 i = 0; i < TunnelPts.Num() - 1; i++)
	{
		const FVector2D A = TunnelPts[i], B = TunnelPts[i + 1];
		const FVector2D D = (B - A).GetSafeNormal();
		const FVector2D Nrm(-D.Y, D.X);
		for (float Side : { -1.f, 1.f })
		{
			const FVector2D Oa = A + Nrm * TunnelW * Side - D * 0.9f, Ob = B + Nrm * TunnelW * Side + D * 0.9f;
			const FVector2D Mp = (Oa + Ob) * 0.5;
			const float Len = FVector2D::Distance(Oa, Ob);
			ADSVisual::AddInstance(Rock, P3(Mp, WallH * 0.5f - 1.2f), FVector(Len, 1.4, WallH), YawOf((Ob - Oa).GetSafeNormal()));
			AddWall(Oa, Ob, 1.4f);
		}
	}
	// arched ribs overhead every ~6 m
	float Carry = 0.f;
	int32 TorchI = 0;
	for (int32 i = 0; i < TunnelPts.Num() - 1; i++)
	{
		const FVector2D A = TunnelPts[i], B = TunnelPts[i + 1];
		const float Seg = FVector2D::Distance(A, B);
		const FVector2D D = (B - A).GetSafeNormal();
		float Pos = Carry;
		while (Pos < Seg)
		{
			const FVector2D C = FMath::Lerp(A, B, Pos / Seg);
			const float Perp = YawOf(FVector2D(-D.Y, D.X));
			ADSVisual::AddInstance(Rock, P3(C, 5.9f), FVector(TunnelW * 2.0 + 2.2, 1.1, 0.9), Perp);
			ADSVisual::AddInstance(Rock, P3(C, 6.6f), FVector(TunnelW * 2.0 + 0.6, 0.7, 0.5), Perp);
			if (TorchI % 2 == 0)
			{
				const float Side = (TorchI / 2) % 2 == 0 ? 1.f : -1.f;
				const FVector2D Tp = C + FVector2D(-D.Y, D.X) * (TunnelW - 0.8f) * Side;
				MakeTorchProp(W, P3(Tp), FLinearColor(1.f, 0.7f, 0.28f));
			}
			TorchI++;
			Pos += 6.f;
		}
		Carry = Pos - Seg;
	}
	// portal gates with skull reliefs at both ends
	for (int32 End : { 1, TunnelPts.Num() - 2 })
	{
		const FVector2D Pc = TunnelPts[End];
		const FVector2D Pd = (TunnelPts[FMath::Min(End + 1, TunnelPts.Num() - 1)] - TunnelPts[FMath::Max(End - 1, 0)]).GetSafeNormal();
		const FVector2D Pn(-Pd.Y, Pd.X);
		for (float Side : { -1.f, 1.f })
		{
			const FVector2D Pp = Pc + Pn * (TunnelW + 0.6f) * Side;
			ADSVisual::AddInstance(Rock, P3(Pp, 4.2f), FVector(2.2, 2.2, 9.0), YawOf(Pd));
		}
		ADSVisual::AddInstance(Rock, P3(Pc, 8.6f), FVector(TunnelW * 2.0 + 5.0, 2.4, 2.0), YawOf(Pn));
		ADSVisual::AddInstance(Rock, P3(Pc, 7.1f), FVector(TunnelW * 2.0 + 1.0, 1.6, 1.0), YawOf(Pn));
		for (int32 k = 0; k < 5; k++)
		{
			const FVector2D Sp = Pc + Pn * FMath::Lerp(-3.6f, 3.6f, k / 4.f) - Pd * 1.3f;
			ADSVisual* Skull = W->SpawnActor<ADSVisual>(P3(Sp, 7.5f), FRotator::ZeroRotator);
			Skull->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.64, 0.64, 0.74), FLinearColor(0.85f, 0.82f, 0.72f));
			Skull->SetShadows(false);
		}
		MakeTorchProp(W, P3(Pc + Pn * (TunnelW + 2.4f)), FLinearColor(1.f, 0.6f, 0.25f));
		MakeTorchProp(W, P3(Pc - Pn * (TunnelW + 2.4f)), FLinearColor(1.f, 0.6f, 0.25f));
	}
	// a few real lights inside (kept few for mobile)
	for (float F : { 0.25f, 0.55f, 0.85f })
	{
		const FVector2D Lp = TunnelPts[(int32)(F * (TunnelPts.Num() - 1))];
		if (APointLight* L = W->SpawnActor<APointLight>(P3(Lp, 3.4f), FRotator::ZeroRotator))
		{
			L->GetRootComponent()->SetMobility(EComponentMobility::Movable);
			L->GetLightComponent()->SetLightColor(FLinearColor(1.f, 0.63f, 0.31f));
			L->GetLightComponent()->SetIntensity(6000.f);
			DSSetLightRadius(L, 1600.f);
		}
	}
	// bones, barrels and crates along the sides
	FRandomStream Rng(404);
	for (int32 k = 0; k < 26; k++)
	{
		const int32 I = Rng.RandRange(1, TunnelPts.Num() - 2);
		const FVector2D A = TunnelPts[I], B = TunnelPts[I + 1];
		const FVector2D D = (B - A).GetSafeNormal(), N(-D.Y, D.X);
		const float Side = Rng.FRand() < 0.5f ? 1.f : -1.f;
		const FVector2D Pp = FMath::Lerp(A, B, Rng.FRand()) + N * Side * Rng.FRandRange(2.8f, TunnelW - 1.f);
		ADSVisual* V = W->SpawnActor<ADSVisual>(P3(Pp), FRotator(0, Rng.FRand() * 360.f, 0));
		switch (k % 3)
		{
		case 0: V->AddPart(EDSShape::Sphere, FVector(0, 0, 0.22), FVector(0.5, 0.5, 0.56), FLinearColor(0.8f, 0.78f, 0.66f)); break;
		case 1: V->AddPart(EDSShape::Cylinder, FVector(0, 0, 0.45), FVector(0.8, 0.8, 0.9), FLinearColor(0.23f, 0.15f, 0.09f)); break;
		default: V->AddPart(EDSShape::Cube, FVector(0, 0, 0.4), FVector(0.9, 0.9, 0.8), FLinearColor(0.23f, 0.15f, 0.09f)); break;
		}
		V->SetShadows(false);
	}
}

float ADSGame::TunnelDepth(const FVector2D& P) const
{
	if (TunnelPts.Num() < 2) return 0.f;
	float Best = 1e9f;
	for (int32 i = 0; i < TunnelPts.Num() - 1; i++)
	{
		const FVector2D A = TunnelPts[i], Ab = TunnelPts[i + 1] - A;
		const float T = FMath::Clamp(FVector2D::DotProduct(P - A, Ab) / FMath::Max(Ab.SizeSquared(), 0.0001), 0.0, 1.0);
		Best = FMath::Min(Best, (float)FVector2D::Distance(P, A + Ab * T));
	}
	return FMath::Clamp(1.f - (Best - (TunnelW - 1.f)) / 4.f, 0.f, 1.f);
}

// ================================================================== labyrinth

void ADSGame::BuildMaze(const FVector2D& Center, const FVector2D& Travel)
{
	if (Maze.bBuilt) return;
	UWorld* W = GetWorld();
	const int32 N = 15;
	const float Cell = 6.f;
	const float Size = N * Cell;
	const FVector2D Origin = Center - FVector2D(Size, Size) * 0.5;
	const float Base = Ground(Center);
	FRandomStream Rng(2727);
	// vw[i][j]: wall on vertical line i beside row j; hw[i][j]: wall on horizontal line j beside column i
	TArray<TArray<bool>> Vw, Hw;
	Vw.SetNum(N + 1); Hw.SetNum(N + 1);
	for (int32 i = 0; i <= N; i++) { Vw[i].Init(true, N + 1); Hw[i].Init(true, N + 1); }
	// recursive-backtracker carve
	TArray<TArray<bool>> Seen;
	Seen.SetNum(N);
	for (int32 i = 0; i < N; i++) Seen[i].Init(false, N);
	TArray<FIntPoint> Stack;
	Stack.Add(FIntPoint(Rng.RandRange(0, N - 1), Rng.RandRange(0, N - 1)));
	Seen[Stack[0].X][Stack[0].Y] = true;
	const FIntPoint Dirs[4] = { FIntPoint(1, 0), FIntPoint(-1, 0), FIntPoint(0, 1), FIntPoint(0, -1) };
	while (Stack.Num() > 0)
	{
		const FIntPoint Cur = Stack.Last();
		TArray<FIntPoint> Opts;
		for (const FIntPoint& D : Dirs)
		{
			const FIntPoint Nb = Cur + D;
			if (Nb.X >= 0 && Nb.Y >= 0 && Nb.X < N && Nb.Y < N && !Seen[Nb.X][Nb.Y]) Opts.Add(D);
		}
		if (Opts.IsEmpty()) { Stack.Pop(); continue; }
		const FIntPoint D2 = Opts[Rng.RandRange(0, Opts.Num() - 1)];
		const FIntPoint Nb2 = Cur + D2;
		if (D2.X == 1) Vw[Cur.X + 1][Cur.Y] = false;
		else if (D2.X == -1) Vw[Cur.X][Cur.Y] = false;
		else if (D2.Y == 1) Hw[Cur.X][Cur.Y + 1] = false;
		else Hw[Cur.X][Cur.Y] = false;
		Seen[Nb2.X][Nb2.Y] = true;
		Stack.Add(Nb2);
	}
	// entrance on the side the player arrives from, exit on the opposite side
	const int32 Mid = N / 2;
	FIntPoint Entrance(Mid, 0), Exit(Mid, N - 1);
	if (FMath::Abs(Travel.X) > FMath::Abs(Travel.Y))
	{
		Vw[0][Mid] = false; Vw[N][Mid] = false;
		if (Travel.X > 0.f) { Entrance = FIntPoint(0, Mid); Exit = FIntPoint(N - 1, Mid); }
		else { Entrance = FIntPoint(N - 1, Mid); Exit = FIntPoint(0, Mid); }
	}
	else
	{
		Hw[Mid][0] = false; Hw[Mid][N] = false;
		if (Travel.Y > 0.f) { Entrance = FIntPoint(Mid, 0); Exit = FIntPoint(Mid, N - 1); }
		else { Entrance = FIntPoint(Mid, N - 1); Exit = FIntPoint(Mid, 0); }
	}
	// walls
	ADSVisual* Holder = W->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
	Maze.Actors.Add(Holder);
	UInstancedStaticMeshComponent* Stone = Holder->AddInstanced(EDSShape::Cube, FLinearColor(0.3f, 0.3f, 0.32f));
	const float Wh = 11.f;
	for (int32 i = 0; i <= N; i++)
		for (int32 j = 0; j < N; j++)
			if (Vw[i][j])
			{
				const FVector2D A = Origin + FVector2D(i * Cell, j * Cell), B = Origin + FVector2D(i * Cell, (j + 1) * Cell);
				ADSVisual::AddInstance(Stone, P3((A + B) * 0.5, Wh * 0.5f - 3.3f), FVector(1.4, Cell + 1.4, Wh), 0.f);
				AddWall(A, B, 1.4f);
			}
	for (int32 j = 0; j <= N; j++)
		for (int32 i = 0; i < N; i++)
			if (Hw[i][j])
			{
				const FVector2D A = Origin + FVector2D(i * Cell, j * Cell), B = Origin + FVector2D((i + 1) * Cell, j * Cell);
				ADSVisual::AddInstance(Stone, P3((A + B) * 0.5, Wh * 0.5f - 3.3f), FVector(Cell + 1.4, 1.4, Wh), 0.f);
				AddWall(A, B, 1.4f);
			}
	auto CellPos = [&](const FIntPoint& C) { return Origin + FVector2D((C.X + 0.5) * Cell, (C.Y + 0.5) * Cell); };
	auto OpenTo = [&](const FIntPoint& C, const FIntPoint& D)
	{
		if (D.X == 1) return !Vw[C.X + 1][C.Y];
		if (D.X == -1) return !Vw[C.X][C.Y];
		if (D.Y == 1) return !Hw[C.X][C.Y + 1];
		return !Hw[C.X][C.Y];
	};
	for (const FIntPoint& C : { Entrance, Exit })
		Maze.Actors.Add(MakeTorchProp(W, P3(CellPos(C)), FLinearColor(1.f, 0.82f, 0.44f)));

	// BFS depth from the entrance, then pick dead ends for the treasure
	TMap<int64, int32> Depth;
	Depth.Add(CellKey(Entrance.X, Entrance.Y), 0);
	TArray<FIntPoint> Queue;
	Queue.Add(Entrance);
	for (int32 Qi = 0; Qi < Queue.Num(); Qi++)
	{
		const FIntPoint Cur = Queue[Qi];
		for (const FIntPoint& D : Dirs)
		{
			const FIntPoint Nb = Cur + D;
			if (Nb.X < 0 || Nb.Y < 0 || Nb.X >= N || Nb.Y >= N || Depth.Contains(CellKey(Nb.X, Nb.Y))) continue;
			if (OpenTo(Cur, D)) { Depth.Add(CellKey(Nb.X, Nb.Y), Depth[CellKey(Cur.X, Cur.Y)] + 1); Queue.Add(Nb); }
		}
	}
	auto DepthOf = [&](const FIntPoint& C) { const int32* V = Depth.Find(CellKey(C.X, C.Y)); return V ? *V : -1; };
	TArray<FIntPoint> Dead;
	for (int32 i = 0; i < N; i++)
		for (int32 j = 0; j < N; j++)
		{
			const FIntPoint C(i, j);
			if (C == Entrance || C == Exit || DepthOf(C) < 0) continue;
			int32 Openings = 0;
			for (const FIntPoint& D : Dirs) if (OpenTo(C, D)) Openings++;
			if (Openings == 1) Dead.Add(C);
		}
	Dead.Sort([&](const FIntPoint& A, const FIntPoint& B) { return DepthOf(A) > DepthOf(B); });
	static const int32 Kinds[] = { 0, 1, 2, 1, 3, 1, 2 };     // gun, ammo, souls, ammo, potion, ammo, souls
	TArray<FIntPoint> Chosen;
	for (const FIntPoint& C : Dead)
	{
		bool bOk = true;
		for (const FIntPoint& O : Chosen) if ((FVector2D(C.X, C.Y) - FVector2D(O.X, O.Y)).Size() < 4.0) bOk = false;
		if (bOk) Chosen.Add(C);
		if (Chosen.Num() >= UE_ARRAY_COUNT(Kinds)) break;
	}
	for (int32 k = 0; k < Chosen.Num(); k++)
	{
		FDSChest Ch;
		Ch.Pos = CellPos(Chosen[k]);
		Ch.Kind = Kinds[k];
		ADSVisual* V = W->SpawnActor<ADSVisual>(P3(Ch.Pos), FRotator::ZeroRotator);
		V->AddPart(EDSShape::Cube, FVector(0, 0, 0.35), FVector(1.3, 0.85, 0.7), FLinearColor(0.29f, 0.17f, 0.09f));             // 0 body
		V->AddPart(EDSShape::Cube, FVector(0, 0, 0.84), FVector(1.3, 0.85, 0.28), FLinearColor(0.85f, 0.69f, 0.31f));            // 1 lid
		V->AddPart(EDSShape::Cylinder, FVector(0, 0, 11.0), FVector(Ch.Kind == 0 ? 0.7 : 0.45, Ch.Kind == 0 ? 0.7 : 0.45, 22.0),
			Ch.Kind == 0 ? FLinearColor(1.f, 0.85f, 0.4f) * 2.f : FLinearColor(0.7f, 0.85f, 1.f));                                // 2 light beam
		V->SetShadows(false);
		Ch.Node = V;
		Maze.Chests.Add(Ch);
	}
	// civilians hide in the other dead ends, well spread out
	TArray<FIntPoint> Pool = Dead;
	for (int32 i = Pool.Num() - 1; i > 0; i--) Pool.Swap(i, Rng.RandRange(0, i));
	TArray<FIntPoint> AllCells;
	for (const TPair<int64, int32>& P : Depth) AllCells.Add(FIntPoint((int32)(P.Key >> 32), (int32)(uint32)(P.Key & 0xffffffff)));
	AllCells.Sort([&](const FIntPoint& A, const FIntPoint& B) { return DepthOf(A) > DepthOf(B); });
	TArray<FIntPoint> CivCells;
	for (int32 Pass = 0; Pass < 3; Pass++)
	{
		const TArray<FIntPoint>& Source = Pass < 2 ? Pool : AllCells;
		const int32 MinDepth = Pass == 0 ? 6 : 3;
		const float Gap = Pass == 0 ? 4.f : 3.2f;
		for (const FIntPoint& C : Source)
		{
			if (CivCells.Num() >= 6) break;
			if (Chosen.Contains(C) || C == Entrance || C == Exit || DepthOf(C) < MinDepth) continue;
			bool bFar = true;
			for (const FIntPoint& O : CivCells) if ((FVector2D(C.X, C.Y) - FVector2D(O.X, O.Y)).Size() < Gap) bFar = false;
			for (const FIntPoint& O : Chosen) if ((FVector2D(C.X, C.Y) - FVector2D(O.X, O.Y)).Size() < Gap) bFar = false;
			if (bFar) CivCells.Add(C);
		}
	}
	for (const FIntPoint& C : CivCells) Maze.CivSpots.Add(CellPos(C));
	for (const FIntPoint& C : Dead) Maze.Dead.Add(CellPos(C));
	// sconces along the walls
	FRandomStream Tr(99);
	for (int32 k = 0; k < 14; k++)
	{
		const FIntPoint Tc(Tr.RandRange(0, N - 1), Tr.RandRange(0, N - 1));
		const FVector2D Tp = CellPos(Tc) + FVector2D(Tr.FRandRange(-1.8f, 1.8f), Tr.FRandRange(-1.8f, 1.8f));
		Maze.Actors.Add(MakeTorchProp(W, P3(Tp), FLinearColor(1.f, 0.6f, 0.25f)));
	}
	Maze.bBuilt = true;
	Maze.Center = Center;
	Maze.Origin = Origin;
	Maze.Cell = Cell;
	Maze.N = N;
	Maze.Size = Size;
	Maze.Entrance = CellPos(Entrance);
	Maze.Exit = CellPos(Exit);
	Clearings.Add(Center);
	EmblemsMazeBuilt();
}

float ADSGame::MazeMargin(const FVector2D& P) const
{
	if (!Maze.bBuilt) return -99.f;
	const FVector2D O = Maze.Origin;
	const float Sz = Maze.N * Maze.Cell;
	return FMath::Min(FMath::Min(P.X - O.X, O.X + Sz - P.X), FMath::Min(P.Y - O.Y, O.Y + Sz - P.Y));
}

bool ADSGame::InMaze(const FVector2D& P) const
{
	return Maze.bBuilt && MazeMargin(P) > 0.f;
}

TArray<FVector2D> ADSGame::MazeSpawnPoints(int32 Count, const FVector2D& Avoid, const TArray<FVector2D>& KeepClear) const
{
	TArray<FVector2D> Out, Pool = Maze.Dead;
	for (int32 i = Pool.Num() - 1; i > 0; i--) Pool.Swap(i, FMath::RandRange(0, i));
	for (const FVector2D& P : Pool)
	{
		if (FVector2D::Distance(P, Avoid) > 14.f)
		{
			bool bSpread = true;
			for (const FVector2D& K : KeepClear) if (FVector2D::Distance(P, K) < 11.f) bSpread = false;
			for (const FVector2D& O : Out) if (FVector2D::Distance(P, O) < 8.f) bSpread = false;
			if (bSpread) Out.Add(P);
		}
		if (Out.Num() >= Count) break;
	}
	return Out;
}

int32 ADSGame::ChestNear(const FVector2D& P, float Reach) const
{
	for (int32 i = 0; i < Maze.Chests.Num(); i++)
		if (!Maze.Chests[i].bOpened && FVector2D::Distance(P, Maze.Chests[i].Pos) < Reach) return i;
	return -1;
}

void ADSGame::OpenMazeChest(int32 I)
{
	FDSChest& C = Maze.Chests[I];
	C.bOpened = true;
	C.T = 0.f;
	Burst(C.Pos, 24, FLinearColor(1.f, 0.84f, 0.44f), 8.f, 1.f);
	Sfx(TEXT("chime"), -4.f, 0.9f);
	switch (C.Kind)
	{
	case 0:
		WeaponsOwned[(int32)EDSWeapon::Gun] = true;
		Ammo = FMath::Min(99, Ammo + 24);
		EquipWeapon(EDSWeapon::Gun);
		ShowBanner(TEXT("ASHEN REVOLVER FOUND"), 3.5f, TEXT("24 ammo - tap SWAP to switch weapons"));
		Strike(C.Pos);
		break;
	case 1:
		Ammo = FMath::Min(99, Ammo + 14);
		Float(P3(C.Pos, 2.2f), TEXT("+14 AMMO"), FLinearColor(1.f, 0.82f, 0.44f));
		break;
	case 2:
	{
		const int32 Amt = 250 + 25 * QuestN;
		Souls += Amt;
		Float(P3(C.Pos, 2.2f), FString::Printf(TEXT("+%d SOULS"), Amt), FLinearColor(0.95f, 0.82f, 0.48f));
		break;
	}
	default:
		Flasks = FMath::Min(9, Flasks + 2);
		Float(P3(C.Pos, 2.2f), TEXT("+2 POTIONS"), FLinearColor(1.f, 0.7f, 0.28f));
		break;
	}
}

void ADSGame::UpdateChests(float Dt)
{
	for (FDSChest& C : Maze.Chests)
	{
		if (C.T < 0.f || !C.Node.IsValid()) continue;
		C.T += Dt;
		if (UStaticMeshComponent* Lid = C.Node->GetPart(1)) Lid->SetRelativeRotation(FRotator(FMath::Clamp(C.T / 0.7f, 0.f, 1.f) * 75.f, 0, 0));
		if (C.T > 0.7f) if (UStaticMeshComponent* Beam = C.Node->GetPart(2)) Beam->SetVisibility(false);
	}
}

void ADSGame::MazeFailed(const FString& Reason)
{
	if (MazeFailT >= 0.f) return;
	MazeFailT = 0.f;
	ShowBanner(TEXT("QUEST FAILED"), 3.4f, Reason);
	Shake = 12.f;
}

// ================================================================== torch

void ADSGame::TorchEnter()
{
	if (bTorchActive) return;
	bTorchActive = bTorchHeld = true;
	if (!TorchLight)
	{
		TorchLight = GetWorld()->SpawnActor<APointLight>(FVector::ZeroVector, FRotator::ZeroRotator);
		TorchLight->GetRootComponent()->SetMobility(EComponentMobility::Movable);
		TorchLight->GetLightComponent()->SetLightColor(FLinearColor(1.f, 0.62f, 0.28f));
		DSSetLightRadius(TorchLight, 1700.f);
		TorchLight->GetLightComponent()->SetCastShadows(false);
	}
	TorchLight->SetActorHiddenInGame(false);
	ShowBanner(TEXT("THE LABYRINTH IS DARK"), 3.2f, TEXT("Drag the right side of the screen to look  -  drop the torch to fight"));
	Sfx(TEXT("crumble"), -6.f, 1.4f);
}

void ADSGame::TorchLeave()
{
	if (!bTorchActive) return;
	bTorchActive = bTorchHeld = false;
	TorchGround = FVector2D(1e9, 1e9);
	if (TorchFloor.IsValid()) TorchFloor->Destroy();
	if (TorchLight) TorchLight->SetActorHiddenInGame(true);
	if (TorchFloorLight) TorchFloorLight->SetActorHiddenInGame(true);
}

bool ADSGame::TorchCanPick() const
{
	return bTorchActive && !bTorchHeld && TorchGround.X < 1e8 && FVector2D::Distance(PPos, TorchGround) < 3.2f;
}

void ADSGame::TorchToggle()
{
	if (!bTorchActive || State != EDSState::Play || IsFrozen()) return;
	if (PAct != EDSAct::Idle && PAct != EDSAct::Block) return;
	if (bTorchHeld)
	{
		bTorchHeld = false;
		TorchGround = PPos + FromAngle(PFace) * 1.f;
		ADSVisual* V = MakeTorchProp(GetWorld(), P3(TorchGround), FLinearColor(1.f, 0.7f, 0.28f));
		TorchFloor = V;
		if (!TorchFloorLight)
		{
			TorchFloorLight = GetWorld()->SpawnActor<APointLight>(FVector::ZeroVector, FRotator::ZeroRotator);
			TorchFloorLight->GetRootComponent()->SetMobility(EComponentMobility::Movable);
			TorchFloorLight->GetLightComponent()->SetLightColor(FLinearColor(1.f, 0.62f, 0.28f));
			DSSetLightRadius(TorchFloorLight, 1700.f);
			TorchFloorLight->GetLightComponent()->SetCastShadows(false);
		}
		TorchFloorLight->SetActorHiddenInGame(false);
		TorchFloorLight->SetActorLocation(P3(TorchGround, 1.8f));
		Burst(TorchGround, 6, FLinearColor(1.f, 0.7f, 0.3f), 4.f, 0.3f);
		Sfx(TEXT("crumble"), -4.f, 1.f);
		Float(P3(PPos, 2.5f), TEXT("TORCH DROPPED"), FLinearColor(1.f, 0.7f, 0.3f));
	}
	else if (TorchCanPick())
	{
		bTorchHeld = true;
		TorchGround = FVector2D(1e9, 1e9);
		if (TorchFloor.IsValid()) TorchFloor->Destroy();
		if (TorchFloorLight) TorchFloorLight->SetActorHiddenInGame(true);
		Sfx(TEXT("swing"), -8.f, 0.7f);
		Float(P3(PPos, 2.5f), TEXT("TORCH"), FLinearColor(1.f, 0.7f, 0.3f));
	}
}

void ADSGame::TorchUpdate(float Dt)
{
	const float Mz = MazeMargin(PPos);
	if (Mz > 2.f && !bTorchActive && bHasWeapon) TorchEnter();
	else if (Mz < -4.f && bTorchActive) TorchLeave();
	if (!bTorchActive) return;
	const float Flick = 1.f + 0.1f * FMath::Sin(Time * 13.f) + 0.06f * FMath::Sin(Time * 29.f + 1.f) + FMath::FRandRange(-0.04f, 0.04f);
	if (TorchLight && bTorchHeld)
	{
		TorchLight->SetActorLocation(P3(PPos, 2.3f) + FVector(FMath::Cos(PFace), FMath::Sin(PFace), 0.f) * 60.0);
		TorchLight->GetLightComponent()->SetIntensity(9000.f * Flick);
		TorchLight->SetActorHiddenInGame(false);
	}
	else if (TorchLight) TorchLight->SetActorHiddenInGame(true);
	if (TorchFloorLight && !bTorchHeld) TorchFloorLight->GetLightComponent()->SetIntensity(8000.f * Flick);
}

// ================================================================== civilians

void ADSGame::CivClear()
{
	for (FDSCivilian& C : Civs)
	{
		if (C.Fig.IsValid()) C.Fig->Destroy();
		if (C.Beam.IsValid()) C.Beam->Destroy();
	}
	Civs.Reset();
	CivTrail.Reset();
	CivTotal = CivRescued = 0;
	bCivStay = bCivFreed = false;
}

void ADSGame::CivSpawn(const TArray<FVector2D>& Spots)
{
	CivClear();
	for (int32 i = 0; i < Spots.Num(); i++)
	{
		FDSCivilian C;
		C.Pos = Spots[i];
		C.Face = FMath::FRand() * 2.f * PI;
		C.T = FMath::FRand() * 6.f;
		const FLinearColor Cloth = i % 2 == 0 ? FLinearColor(0.45f, 0.33f, 0.2f) : FLinearColor(0.35f, 0.2f, 0.3f);
		ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(C.Pos), FRotator::ZeroRotator);
		V->AddPart(EDSShape::Cylinder, FVector(0, 0, 0.8), FVector(0.55, 0.55, 1.0), Cloth);
		V->AddPart(EDSShape::Sphere, FVector(0, 0, 1.55), FVector(0.38), FLinearColor(0.75f, 0.6f, 0.5f));
		V->SetShadows(false);
		C.Fig = V;
		ADSVisual* B = GetWorld()->SpawnActor<ADSVisual>(P3(C.Pos, 12.f), FRotator::ZeroRotator);
		B->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(0.6, 0.6, 24.0), FLinearColor(0.5f, 0.9f, 1.f));
		B->SetShadows(false);
		C.Beam = B;
		Civs.Add(C);
	}
	CivTotal = Civs.Num();
}

int32 ADSGame::CivNear(const FVector2D& P, float Reach) const
{
	for (int32 i = 0; i < Civs.Num(); i++)
		if (Civs[i].State == 0 && FVector2D::Distance(P, Civs[i].Pos) < Reach) return i;
	return -1;
}

int32 ADSGame::CivCount(int32 WantState) const
{
	int32 N = 0;
	for (const FDSCivilian& C : Civs) if (C.State == WantState) N++;
	return N;
}

bool ADSGame::CivAllSaved() const
{
	if (CivTotal == 0) return false;
	for (const FDSCivilian& C : Civs) if (C.State != 4) return false;
	return true;
}

void ADSGame::CivRescue(int32 I)
{
	FDSCivilian& C = Civs[I];
	C.State = 1;
	C.Order = CivRescued++;
	if (C.Beam.IsValid()) C.Beam->Destroy();
	Burst(C.Pos, 16, FLinearColor(0.6f, 0.87f, 1.f), 7.f, 1.2f);
	Sfx(TEXT("chime"), -4.f, 1.3f);
	Float(P3(C.Pos, 2.4f), FString::Printf(TEXT("RESCUED  %d / %d"), CivRescued, CivTotal), FLinearColor(0.6f, 0.87f, 1.f));
	if (CivRescued >= CivTotal) ShowBanner(TEXT("EVERYONE IS FREE"), 2.6f, TEXT("Keep them alive and lead them to the far gate"));
}

void ADSGame::CivCommand()
{
	const int32 Following = CivCount(1) + CivCount(2);
	if (CivRescued <= 0 || Following <= 0) { ShowBanner(TEXT("NOBODY TO COMMAND"), 1.4f, TEXT("Rescue a civilian first")); return; }
	bCivStay = CivCount(1) > 0;
	for (FDSCivilian& C : Civs) if (C.State == 1 || C.State == 2) C.State = bCivStay ? 2 : 1;
	Sfx(TEXT("chime"), -8.f, bCivStay ? 1.f : 1.4f);
	Float(P3(PPos, 2.7f), bCivStay ? TEXT("STAY HERE") : TEXT("FOLLOW ME"), FLinearColor(0.6f, 0.87f, 1.f));
	ShowBanner(bCivStay ? TEXT("CIVILIANS: STAY") : TEXT("CIVILIANS: FOLLOW"), 1.6f, bCivStay ? TEXT("They will wait here until you call them") : TEXT("They follow you in single file"));
}

void ADSGame::CivUpdate(float Dt)
{
	if (Civs.IsEmpty()) return;
	if (CivTrail.IsEmpty() || FVector2D::Distance(PPos, CivTrail.Last()) > 0.7f)
	{
		CivTrail.Add(PPos);
		if (CivTrail.Num() > 600) CivTrail.RemoveAt(0);
	}
	const FVector2D ExitP = Maze.bBuilt ? Maze.Exit : PPos;
	const FVector2D OutDir = Maze.bBuilt ? (Maze.Exit - Maze.Center).GetSafeNormal() : FVector2D(1, 0);
	// everyone free and gathered at the gate: they run out to safety
	if (CivRescued >= CivTotal && !bCivFreed && FVector2D::Distance(PPos, ExitP) < 10.f)
	{
		bool bNear = true;
		for (const FDSCivilian& C : Civs) if (C.State != 5 && FVector2D::Distance(C.Pos, ExitP) > 16.f) bNear = false;
		if (bNear)
		{
			bCivFreed = true;
			CivFreeT = 0.f;
			for (FDSCivilian& C : Civs) C.State = 3;
			Sfx(TEXT("chime"), -2.f, 1.1f);
			Burst(ExitP, 24, FLinearColor(1.f, 0.91f, 0.66f), 8.f, 1.4f);
			ShowBanner(TEXT("CIVILIANS SAVED"), 3.f, FString::Printf(TEXT("+%d SOULS"), 120 * CivTotal));
			Souls += 120 * CivTotal;
		}
	}
	if (bCivFreed) CivFreeT += Dt;
	TArray<int32> Followers;
	for (int32 i = 0; i < Civs.Num(); i++) if (Civs[i].State == 1) Followers.Add(i);
	Followers.Sort([&](int32 A, int32 B) { return Civs[A].Order < Civs[B].Order; });
	for (int32 i = 0; i < Civs.Num(); i++)
	{
		FDSCivilian& C = Civs[i];
		C.HitT = FMath::Max(0.f, C.HitT - Dt);
		ADSVisual* Fig = C.Fig.Get();
		if (!Fig || C.State == 4) continue;
		// monsters maul any civilian they reach; enemy shots that hit one are stopped by it
		if ((C.State == 0 || C.State == 1 || C.State == 2) && MazeFailT < 0.f && !bExecActive)
		{
			const float ReachAdd = C.State == 1 ? 1.9f : 1.5f;
			bool bDone = false;
			if (C.HitT <= 0.f)
				for (const FDSEnemyPtr& E : Enemies)
				{
					if (E->bDead || E->Type == EDSEnemy::Fist || E->bStatic || (E->Mode == EDSMode::Idle && !E->bForce)) continue;
					if (FVector2D::Distance(E->Pos, C.Pos) < E->R + ReachAdd) { C.Hp -= DSData::Enemy(E->Type).Dmg * 0.5f; bDone = true; break; }
				}
			for (FDSProjectile& Pr : Projs)
				if (!bDone && Pr.Team == FDSProjectile::ETeam::Enemy && Pr.Life > 0.f && FVector2D::Distance(Pr.Pos, C.Pos) < 0.9f)
				{
					Pr.Life = 0.f;
					C.Hp -= FMath::Max(Pr.Dmg * 0.5f, 6.f);
					bDone = true;
				}
			if (bDone)
			{
				C.HitT = 0.8f;
				Float(P3(C.Pos, 2.6f), TEXT("HIT"), FLinearColor(1.f, 0.42f, 0.35f));
				Burst(C.Pos, 6, FLinearColor(0.63f, 0.06f, 0.1f), 5.f, 1.2f);
				if (C.Hp <= 0.f)
				{
					C.State = 5;
					Burst(C.Pos, 12, FLinearColor(0.63f, 0.06f, 0.1f), 8.f, 1.f);
					MazeFailed(TEXT("A civilian was killed"));
				}
			}
		}
		float Drop = 0.f;
		switch (C.State)
		{
		case 0:
		case 2:
			C.T += Dt;
			if (FVector2D::Distance(PPos, C.Pos) < 14.f) C.Face = AngleOf(PPos - C.Pos);
			Drop = 0.32f;
			break;
		case 1:
		{
			const int32 Rank = Followers.IndexOfByKey(i);
			const int32 Idx = CivTrail.Num() - 1 - 8 * (Rank + 1);
			const FVector2D Target = Idx >= 0 ? CivTrail[Idx] : C.Pos;
			const FVector2D D = Target - C.Pos;
			const float Dl = D.Size();
			if (Dl > 30.f) C.Pos = Target;
			else if (Dl > 0.35f)
			{
				C.Pos += D / Dl * FMath::Min(Dl, (3.4f + FMath::Min(Dl, 4.f) * 0.9f) * Dt);
				C.Face = AngleOf(D);
			}
			break;
		}
		case 3:
		{
			const FVector2D Goal = ExitP + OutDir * 22.f;
			const FVector2D D = Goal - C.Pos;
			if (D.Size() < 1.f || CivFreeT > 14.f) { C.State = 4; Fig->SetActorHiddenInGame(true); continue; }
			C.Pos += D.GetSafeNormal() * 4.6f * Dt;
			C.Face = AngleOf(D);
			break;
		}
		default: break;
		}
		FVector Loc = P3(C.Pos);
		Loc.Z -= Drop * 100.0;
		float Pitch = C.State == 5 ? -85.f : (C.State == 0 || C.State == 2 ? 28.f : 0.f);
		if (C.HitT > 0.f) Loc.X += FMath::Sin(Time * 60.f) * 3.0;
		Fig->SetActorLocationAndRotation(Loc, FRotator(Pitch, FMath::RadiansToDegrees(C.Face), 0));
	}
}

// ================================================================== bridge

void ADSGame::BuildBridge(const FVector2D& Center, const FVector2D& D)
{
	if (Bridge.bBuilt) return;
	UWorld* W = GetWorld();
	const FVector2D N(-D.Y, D.X);
	Bridge.bBuilt = true;
	Bridge.Center = Center;
	Bridge.D = D;
	Bridge.N = N;
	// the chasm is baked into the exported heightmap; the approach ground (just before the cliff edge) gives the deck level
	Bridge.Base = Ground(Center - D * (Bridge.HalfLen + 2.f));
	const float Base = Bridge.Base;
	Bridge.BossPos = Center + D * (Bridge.HalfLen + 10.f);
	ADSVisual* Holder = W->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
	UInstancedStaticMeshComponent* Stone = Holder->AddInstanced(EDSShape::Cube, RockCol);
	const float Yaw = YawOf(D);
	auto Box = [&](const FVector2D& P, float Z, const FVector& Size) { ADSVisual::AddInstance(Stone, FVector(P.X * 100.0, P.Y * 100.0, (Base + Z) * 100.0), Size, Yaw); };
	Box(Center, -0.45f, FVector(Bridge.HalfLen * 2.f + 1.f, Bridge.HalfW * 2.f, 0.9));
	for (float Side : { -1.f, 1.f })
	{
		Box(Center + N * (Bridge.HalfW - 0.2f) * Side, 0.45f, FVector(Bridge.HalfLen * 2.f + 2.f, 0.5, 0.9));
		for (int32 k = -5; k <= 5; k++) Box(Center + D * (k * 4.f) + N * (Bridge.HalfW - 0.2f) * Side, 1.1f, FVector(0.7, 0.7, 2.2));
	}
	for (int32 k = -2; k <= 2; k++)
	{
		Box(Center + D * (k * 10.f), -20.f, FVector(2.4, Bridge.HalfW * 1.4, 38.0));
		Box(Center + D * (k * 10.f), -1.3f, FVector(3.2, Bridge.HalfW * 2.f, 1.0));
	}
	for (int32 k : { -4, 0, 4 })
		for (float Side : { -1.f, 1.f })
		{
			const FVector2D Tp = Center + D * (k * 4.5f) + N * (Bridge.HalfW - 0.2f) * Side;
			MakeTorchProp(W, FVector(Tp.X * 100.0, Tp.Y * 100.0, (Base + 1.4f) * 100.0), FLinearColor(1.f, 0.42f, 0.19f));
		}
	// a dark mist plane far below so the chasm reads as a drop
	ADSVisual* Mist = W->SpawnActor<ADSVisual>(FVector(Center.X * 100.0, Center.Y * 100.0, (Base - 30.f) * 100.0), FRotator::ZeroRotator);
	Mist->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(68.0, 68.0, 0.2), FLinearColor(0.01f, 0.015f, 0.03f));
	Mist->SetShadows(false);
	Clearings.Add(Center);
}

bool ADSGame::OnBridge(const FVector2D& P) const
{
	if (!Bridge.bBuilt) return false;
	const FVector2D Rel = P - Bridge.Center;
	return FMath::Abs(FVector2D::DotProduct(Rel, Bridge.D)) < Bridge.HalfLen + 0.4f && FMath::Abs(FVector2D::DotProduct(Rel, Bridge.N)) < Bridge.HalfW + 0.3f;
}

FVector2D ADSGame::BridgeClamp(const FVector2D& P) const
{
	if (!Bridge.bBuilt) return P;
	const FVector2D Rel = P - Bridge.Center;
	const float Lon = FMath::Clamp((float)FVector2D::DotProduct(Rel, Bridge.D), -Bridge.HalfLen - 6.f, Bridge.HalfLen - 0.5f);
	const float Lat = FMath::Clamp((float)FVector2D::DotProduct(Rel, Bridge.N), -Bridge.HalfW + 0.8f, Bridge.HalfW - 0.8f);
	return Bridge.Center + Bridge.D * Lon + Bridge.N * Lat;
}

// ================================================================== forest

bool ADSGame::ForestCleared(const FVector2D& P) const
{
	for (int32 i = 0; i < DSData::RouteNum(); i += 1)
	{
		const FVector2D R = DSData::Route(i);
		if (FMath::Abs(P.X - R.X) > 40.f || FMath::Abs(P.Y - R.Y) > 40.f) continue;
		const float Lim = DSData::RouteClear(i) * 0.5f + 4.5f;
		if (FVector2D::DistSquared(P, R) < Lim * Lim) return true;
	}
	for (const FVector2D& C : Clearings)
		if (FVector2D::DistSquared(P, C) < 55.f * 55.f) return true;
	for (const FVector2D& T : TunnelPts)
		if (FVector2D::DistSquared(P, T) < 26.f * 26.f) return true;
	return WallOnly(P, 3.f);
}

FVector2D ADSGame::NearestTree(const FVector2D& P, float Reach) const
{
	FVector2D Best(1e9, 1e9);
	float Bd = Reach * Reach;
	const int32 Cx = FMath::FloorToInt(P.X / 6.0), Cy = FMath::FloorToInt(P.Y / 6.0), R = FMath::CeilToInt(Reach / 6.f);
	for (int32 Dx = -R; Dx <= R; Dx++)
		for (int32 Dy = -R; Dy <= R; Dy++)
			if (const TArray<FVector>* T = Trunks.Find(CellKey(Cx + Dx, Cy + Dy)))
				for (const FVector& V : *T)
				{
					const float D = FVector2D::DistSquared(P, FVector2D(V.X, V.Y));
					if (D < Bd) { Bd = D; Best = FVector2D(V.X, V.Y); }
				}
	return Best;
}

void ADSGame::MakeForestChunk(int32 Cx, int32 Cy)
{
	const int64 Key = CellKey(Cx, Cy);
	const bool bFirst = !ForestChunks.Contains(Key);
	const float Chunk = 40.f;
	FRandomStream Rng((int32)((uint32)Cx * 73856093u ^ (uint32)Cy * 19349663u ^ 4242u));
	const FVector2D Origin(Cx * Chunk, Cy * Chunk);
	UWorld* W = GetWorld();
	ADSVisual* V = W->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
	UInstancedStaticMeshComponent* Trunk = V->AddInstanced(EDSShape::Cylinder, FLinearColor(0.16f, 0.1f, 0.06f));
	UInstancedStaticMeshComponent* Leaf = V->AddInstanced(EDSShape::Cone, FLinearColor(0.04f, 0.13f, 0.07f));
	UInstancedStaticMeshComponent* Bush = V->AddInstanced(EDSShape::Sphere, FLinearColor(0.06f, 0.16f, 0.07f));
	const float Step = 3.7f;
	const int32 Cnt = (int32)(Chunk / Step);
	for (int32 Gx = 0; Gx < Cnt; Gx++)
		for (int32 Gz = 0; Gz < Cnt; Gz++)
		{
			const FVector2D P = Origin + FVector2D((Gx + 0.5f) * Step, (Gz + 0.5f) * Step) + FVector2D(Rng.FRandRange(-2.f, 2.f), Rng.FRandRange(-2.f, 2.f));
			const float Thick = FMath::Clamp(0.92f + 0.5f * FMath::PerlinNoise2D(FVector2D(P.X, P.Y) * 0.011f), 0.3f, 1.f);
			const float Roll = Rng.FRand();
			const float Kind = Rng.FRand(), S = Rng.FRandRange(0.75f, 1.35f), Yaw = Rng.FRand() * 6.28f;
			const float Bx = Rng.FRand(), By = Rng.FRand();
			if (Roll > Thick || ForestCleared(P) || !WalkOk(P)) continue;
			const float H = Ground(P);
			if (FMath::Abs(Ground(P + FVector2D(1.6, 0)) - H) > 2.3f || FMath::Abs(Ground(P + FVector2D(0, 1.6)) - H) > 2.3f) continue;
			const bool bDead = Kind < 0.06f;
			ADSVisual::AddInstance(Trunk, FVector(P.X * 100.0, P.Y * 100.0, (H + 1.6f * S) * 100.0), FVector(0.55 * S, 0.55 * S, 3.2 * S), Yaw);
			if (!bDead)
			{
				ADSVisual::AddInstance(Leaf, FVector(P.X * 100.0, P.Y * 100.0, (H + 4.6f * S) * 100.0), FVector(2.8 * S, 2.8 * S, 6.5 * S), Yaw);
				if (Bx < 0.55f)
				{
					const FVector2D Bp = P + FromAngle(By * 6.28f) * (1.2f + By * 1.4f);
					ADSVisual::AddInstance(Bush, FVector(Bp.X * 100.0, Bp.Y * 100.0, (Ground(Bp) + 0.4f) * 100.0), FVector(1.2, 1.2, 0.8), Yaw);
				}
			}
			if (bFirst)
			{
				const int64 Ck = CellKey(FMath::FloorToInt(P.X / 6.0), FMath::FloorToInt(P.Y / 6.0));
				Trunks.FindOrAdd(Ck).Add(FVector(P.X, P.Y, 0.34f * S));
			}
		}
	ForestChunks.Add(Key, V);
}

void ADSGame::UpdateForest(const FVector2D& Focus)
{
	const float Chunk = 40.f;
	const int32 Cx = FMath::FloorToInt(Focus.X / Chunk), Cy = FMath::FloorToInt(Focus.Y / Chunk);
	const int32 R = 2;
	// build at most one missing chunk per frame, nearest first
	int32 Bx = 0, By = 0, Bd = 1 << 30;
	for (int32 Dx = -R; Dx <= R; Dx++)
		for (int32 Dy = -R; Dy <= R; Dy++)
		{
			const TWeakObjectPtr<ADSVisual>* E = ForestChunks.Find(CellKey(Cx + Dx, Cy + Dy));
			if (E && E->IsValid()) continue;
			if (Dx * Dx + Dy * Dy < Bd) { Bd = Dx * Dx + Dy * Dy; Bx = Cx + Dx; By = Cy + Dy; }
		}
	if (Bd != (1 << 30)) MakeForestChunk(Bx, By);
	// release chunks that are far behind (their trunks stay, so collision is unchanged)
	for (TPair<int64, TWeakObjectPtr<ADSVisual>>& P : ForestChunks)
	{
		if (!P.Value.IsValid()) continue;
		const int32 Kx = (int32)(P.Key >> 32), Ky = (int32)(uint32)(P.Key & 0xffffffff);
		if (FMath::Abs(Kx - Cx) > R + 2 || FMath::Abs(Ky - Cy) > R + 2) P.Value->Destroy();
	}
}
