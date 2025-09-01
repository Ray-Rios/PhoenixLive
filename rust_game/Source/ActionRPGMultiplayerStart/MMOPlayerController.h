#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "GameServerManager.h"
#include "MMOPlayerController.generated.h"

UCLASS(BlueprintType, Blueprintable)
class ACTIONRPGMULTIPLAYERSTART_API AMMOPlayerController : public APlayerController
{
    GENERATED_BODY()

public:
    AMMOPlayerController();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
    virtual void Tick(float DeltaTime) override;

    // Game Server Manager Reference
    UPROPERTY(BlueprintReadOnly, Category = "MMO")
    AGameServerManager* GameServerManager;

    // MMO Settings
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "MMO Settings")
    bool bAutoConnectToServer = true;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "MMO Settings")
    bool bAutoSyncPosition = true;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "MMO Settings")
    float PositionSyncThreshold = 100.0f; // Only sync if moved more than this distance

    // Player Stats (these will sync with server)
    UPROPERTY(BlueprintReadWrite, Category = "Player Stats")
    int32 PlayerHealth = 100;

    UPROPERTY(BlueprintReadWrite, Category = "Player Stats")
    int32 PlayerLevel = 1;

    UPROPERTY(BlueprintReadWrite, Category = "Player Stats")
    int32 PlayerScore = 0;

    UPROPERTY(BlueprintReadWrite, Category = "Player Stats")
    int32 PlayerExperience = 0;

    // MMO Functions
    UFUNCTION(BlueprintCallable, Category = "MMO")
    void ConnectToMMOServer();

    UFUNCTION(BlueprintCallable, Category = "MMO")
    void DisconnectFromMMOServer();

    UFUNCTION(BlueprintCallable, Category = "MMO")
    bool IsConnectedToMMO() const;

    UFUNCTION(BlueprintCallable, Category = "MMO")
    int32 GetOnlinePlayerCount() const;

    UFUNCTION(BlueprintCallable, Category = "MMO")
    void UpdatePlayerStats(int32 Health, int32 Level, int32 Score, int32 Experience);

    UFUNCTION(BlueprintCallable, Category = "MMO")
    TArray<FPlayerData> GetOnlinePlayers() const;

    // Event Handlers
    UFUNCTION()
    void OnServerConnected(const FString& SessionID);

    UFUNCTION()
    void OnServerError(const FString& ErrorMessage);

    UFUNCTION()
    void OnPlayersUpdated(int32 PlayerCount);

private:
    // Position tracking for sync
    FVector LastSyncedPosition;
    float LastPositionSyncTime = 0.0f;
    
    // Stats tracking
    int32 LastSyncedHealth = 100;
    int32 LastSyncedLevel = 1;
    int32 LastSyncedScore = 0;
    int32 LastSyncedExperience = 0;
    
    void CheckAndSyncPosition();
    void CheckAndSyncStats();
};