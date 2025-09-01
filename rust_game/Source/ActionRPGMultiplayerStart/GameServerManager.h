#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Http.h"
#include "Json.h"
#include "Engine/Engine.h"
#include "GameServerManager.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnServerConnected, const FString&, SessionID);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnServerError, const FString&, ErrorMessage);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPlayersUpdated, int32, PlayerCount);

USTRUCT(BlueprintType)
struct FPlayerData
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly)
    FString PlayerID;

    UPROPERTY(BlueprintReadOnly)
    FString SessionID;

    UPROPERTY(BlueprintReadOnly)
    FVector Position;

    UPROPERTY(BlueprintReadOnly)
    FRotator Rotation;

    UPROPERTY(BlueprintReadOnly)
    int32 Health;

    UPROPERTY(BlueprintReadOnly)
    int32 Level;

    UPROPERTY(BlueprintReadOnly)
    int32 Score;

    UPROPERTY(BlueprintReadOnly)
    int32 Experience;

    FPlayerData()
    {
        PlayerID = "";
        SessionID = "";
        Position = FVector::ZeroVector;
        Rotation = FRotator::ZeroRotator;
        Health = 100;
        Level = 1;
        Score = 0;
        Experience = 0;
    }
};

UCLASS(BlueprintType, Blueprintable)
class ACTIONRPGMULTIPLAYERSTART_API AGameServerManager : public AActor
{
    GENERATED_BODY()

public:
    AGameServerManager();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
    virtual void Tick(float DeltaTime) override;

    // Server Configuration
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Server Settings")
    FString ServerURL = TEXT("http://localhost:9069");

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Server Settings")
    float UpdateInterval = 5.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Server Settings")
    FString PlayerID = TEXT("550e8400-e29b-41d4-a716-446655440000");

    // Current State
    UPROPERTY(BlueprintReadOnly, Category = "Server State")
    bool bIsConnected = false;

    UPROPERTY(BlueprintReadOnly, Category = "Server State")
    FString SessionID;

    UPROPERTY(BlueprintReadOnly, Category = "Server State")
    FPlayerData LocalPlayerData;

    UPROPERTY(BlueprintReadOnly, Category = "Server State")
    TArray<FPlayerData> OnlinePlayers;

    // Events
    UPROPERTY(BlueprintAssignable, Category = "Server Events")
    FOnServerConnected OnServerConnected;

    UPROPERTY(BlueprintAssignable, Category = "Server Events")
    FOnServerError OnServerError;

    UPROPERTY(BlueprintAssignable, Category = "Server Events")
    FOnPlayersUpdated OnPlayersUpdated;

    // Public Functions
    UFUNCTION(BlueprintCallable, Category = "Server")
    void ConnectToServer();

    UFUNCTION(BlueprintCallable, Category = "Server")
    void DisconnectFromServer();

    UFUNCTION(BlueprintCallable, Category = "Server")
    void UpdatePlayerPosition(const FVector& Position, const FRotator& Rotation);

    UFUNCTION(BlueprintCallable, Category = "Server")
    void UpdatePlayerStats(int32 Health, int32 Level, int32 Score, int32 Experience);

    UFUNCTION(BlueprintCallable, Category = "Server")
    void RequestOnlinePlayers();

    UFUNCTION(BlueprintCallable, Category = "Server")
    bool IsConnectedToServer() const { return bIsConnected; }

    UFUNCTION(BlueprintCallable, Category = "Server")
    int32 GetOnlinePlayerCount() const { return OnlinePlayers.Num(); }

private:
    // HTTP Request Handlers
    void OnConnectResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful);
    void OnUpdateResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful);
    void OnPlayersResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful);

    // Utility Functions
    FString CreateUpdatePayload() const;
    void ParsePlayerData(const TSharedPtr<FJsonObject>& JsonObject, FPlayerData& OutPlayerData);
    void LogServerMessage(const FString& Message, bool bIsError = false);

    // Timer Management
    FTimerHandle UpdateTimerHandle;
    FTimerHandle PlayersTimerHandle;
    float LastUpdateTime = 0.0f;

    // HTTP Module
    FHttpModule* HttpModule;
};