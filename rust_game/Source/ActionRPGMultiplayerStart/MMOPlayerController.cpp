#include "MMOPlayerController.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"

AMMOPlayerController::AMMOPlayerController()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = true;
}

void AMMOPlayerController::BeginPlay()
{
    Super::BeginPlay();
    
    // Spawn Game Server Manager
    if (GetWorld())
    {
        FActorSpawnParameters SpawnParams;
        SpawnParams.Owner = this;
        SpawnParams.Instigator = GetPawn();
        
        GameServerManager = GetWorld()->SpawnActor<AGameServerManager>(AGameServerManager::StaticClass(), SpawnParams);
        
        if (GameServerManager)
        {
            // Bind to server events
            GameServerManager->OnServerConnected.AddDynamic(this, &AMMOPlayerController::OnServerConnected);
            GameServerManager->OnServerError.AddDynamic(this, &AMMOPlayerController::OnServerError);
            GameServerManager->OnPlayersUpdated.AddDynamic(this, &AMMOPlayerController::OnPlayersUpdated);
            
            UE_LOG(LogTemp, Log, TEXT("🎮 MMO Player Controller initialized with Game Server Manager"));
            
            // Auto-connect if enabled
            if (bAutoConnectToServer)
            {
                // Delay connection slightly to ensure everything is initialized
                FTimerHandle ConnectTimer;
                GetWorld()->GetTimerManager().SetTimer(ConnectTimer, [this]()
                {
                    ConnectToMMOServer();
                }, 1.0f, false);
            }
        }
        else
        {
            UE_LOG(LogTemp, Error, TEXT("❌ Failed to spawn Game Server Manager"));
        }
    }
}

void AMMOPlayerController::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    // Disconnect from server
    if (GameServerManager && GameServerManager->IsConnectedToServer())
    {
        GameServerManager->DisconnectFromServer();
    }
    
    Super::EndPlay(EndPlayReason);
}

void AMMOPlayerController::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);
    
    // Auto-sync position and stats if connected
    if (GameServerManager && GameServerManager->IsConnectedToServer())
    {
        if (bAutoSyncPosition)
        {
            CheckAndSyncPosition();
        }
        
        CheckAndSyncStats();
    }
}

void AMMOPlayerController::ConnectToMMOServer()
{
    if (GameServerManager)
    {
        GameServerManager->ConnectToServer();
    }
    else
    {
        UE_LOG(LogTemp, Error, TEXT("❌ Game Server Manager not available"));
    }
}

void AMMOPlayerController::DisconnectFromMMOServer()
{
    if (GameServerManager)
    {
        GameServerManager->DisconnectFromServer();
    }
}

bool AMMOPlayerController::IsConnectedToMMO() const
{
    return GameServerManager && GameServerManager->IsConnectedToServer();
}

int32 AMMOPlayerController::GetOnlinePlayerCount() const
{
    if (GameServerManager)
    {
        return GameServerManager->GetOnlinePlayerCount();
    }
    return 0;
}

void AMMOPlayerController::UpdatePlayerStats(int32 Health, int32 Level, int32 Score, int32 Experience)
{
    PlayerHealth = Health;
    PlayerLevel = Level;
    PlayerScore = Score;
    PlayerExperience = Experience;
    
    // Stats will be synced automatically on next tick
}

TArray<FPlayerData> AMMOPlayerController::GetOnlinePlayers() const
{
    if (GameServerManager)
    {
        return GameServerManager->OnlinePlayers;
    }
    return TArray<FPlayerData>();
}

void AMMOPlayerController::OnServerConnected(const FString& SessionID)
{
    UE_LOG(LogTemp, Log, TEXT("🎉 MMO Player Controller: Connected to server with session %s"), *SessionID);
    
    // Initialize last synced position
    if (GetPawn())
    {
        LastSyncedPosition = GetPawn()->GetActorLocation();
    }
    
    // Initialize last synced stats
    LastSyncedHealth = PlayerHealth;
    LastSyncedLevel = PlayerLevel;
    LastSyncedScore = PlayerScore;
    LastSyncedExperience = PlayerExperience;
    
    // You can add Blueprint events here or call other initialization functions
}

void AMMOPlayerController::OnServerError(const FString& ErrorMessage)
{
    UE_LOG(LogTemp, Error, TEXT("💥 MMO Server Error: %s"), *ErrorMessage);
    
    // You can show UI error messages here
}

void AMMOPlayerController::OnPlayersUpdated(int32 PlayerCount)
{
    UE_LOG(LogTemp, Log, TEXT("👥 Online players updated: %d"), PlayerCount);
    
    // You can update UI here to show online player count
}

void AMMOPlayerController::CheckAndSyncPosition()
{
    if (!GetPawn())
    {
        return;
    }
    
    FVector CurrentPosition = GetPawn()->GetActorLocation();
    float DistanceMoved = FVector::Dist(CurrentPosition, LastSyncedPosition);
    
    // Only sync if moved significantly
    if (DistanceMoved > PositionSyncThreshold)
    {
        FRotator CurrentRotation = GetPawn()->GetActorRotation();
        GameServerManager->UpdatePlayerPosition(CurrentPosition, CurrentRotation);
        
        LastSyncedPosition = CurrentPosition;
        LastPositionSyncTime = GetWorld()->GetTimeSeconds();
        
        UE_LOG(LogTemp, VeryVerbose, TEXT("📍 Position synced: %s"), *CurrentPosition.ToString());
    }
}

void AMMOPlayerController::CheckAndSyncStats()
{
    // Check if any stats have changed
    bool bStatsChanged = (PlayerHealth != LastSyncedHealth) ||
                        (PlayerLevel != LastSyncedLevel) ||
                        (PlayerScore != LastSyncedScore) ||
                        (PlayerExperience != LastSyncedExperience);
    
    if (bStatsChanged)
    {
        GameServerManager->UpdatePlayerStats(PlayerHealth, PlayerLevel, PlayerScore, PlayerExperience);
        
        // Update last synced values
        LastSyncedHealth = PlayerHealth;
        LastSyncedLevel = PlayerLevel;
        LastSyncedScore = PlayerScore;
        LastSyncedExperience = PlayerExperience;
        
        UE_LOG(LogTemp, Log, TEXT("📊 Stats synced: Health=%d, Level=%d, Score=%d, XP=%d"), 
               PlayerHealth, PlayerLevel, PlayerScore, PlayerExperience);
    }
}