#include "GameServerManager.h"
#include "Engine/World.h"
#include "TimerManager.h"
#include "Interfaces/IHttpResponse.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

AGameServerManager::AGameServerManager()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = true;
    
    // Get HTTP module
    HttpModule = &FHttpModule::Get();
}

void AGameServerManager::BeginPlay()
{
    Super::BeginPlay();
    
    LogServerMessage(TEXT("🎮 MMO Game Server Manager Started"));
    LogServerMessage(FString::Printf(TEXT("🌐 Server URL: %s"), *ServerURL));
    
    // Initialize local player data
    LocalPlayerData.PlayerID = PlayerID;
    LocalPlayerData.Health = 100;
    LocalPlayerData.Level = 1;
    LocalPlayerData.Score = 0;
    LocalPlayerData.Experience = 0;
}

void AGameServerManager::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    // Disconnect from server when ending play
    if (bIsConnected)
    {
        DisconnectFromServer();
    }
    
    // Clear timers
    if (GetWorld())
    {
        GetWorld()->GetTimerManager().ClearTimer(UpdateTimerHandle);
        GetWorld()->GetTimerManager().ClearTimer(PlayersTimerHandle);
    }
    
    Super::EndPlay(EndPlayReason);
}

void AGameServerManager::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);
    
    // Update last update time
    LastUpdateTime += DeltaTime;
}

void AGameServerManager::ConnectToServer()
{
    if (bIsConnected)
    {
        LogServerMessage(TEXT("Already connected to server"));
        return;
    }
    
    LogServerMessage(TEXT("🔄 Connecting to MMO server..."));
    
    // Create HTTP request
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = HttpModule->CreateRequest();
    Request->OnProcessRequestComplete().BindUObject(this, &AGameServerManager::OnConnectResponse);
    Request->SetURL(ServerURL + TEXT("/game/session"));
    Request->SetVerb(TEXT("POST"));
    Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
    
    // Create JSON payload
    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetStringField(TEXT("player_id"), PlayerID);
    JsonObject->SetNumberField(TEXT("x"), LocalPlayerData.Position.X);
    JsonObject->SetNumberField(TEXT("y"), LocalPlayerData.Position.Y);
    JsonObject->SetNumberField(TEXT("z"), LocalPlayerData.Position.Z);
    JsonObject->SetNumberField(TEXT("health"), LocalPlayerData.Health);
    JsonObject->SetNumberField(TEXT("level"), LocalPlayerData.Level);
    JsonObject->SetNumberField(TEXT("score"), LocalPlayerData.Score);
    JsonObject->SetNumberField(TEXT("experience"), LocalPlayerData.Experience);
    
    FString OutputString;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&OutputString);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);
    
    Request->SetContentAsString(OutputString);
    Request->ProcessRequest();
}

void AGameServerManager::DisconnectFromServer()
{
    if (!bIsConnected)
    {
        return;
    }
    
    LogServerMessage(TEXT("🔌 Disconnecting from MMO server..."));
    
    // Clear timers
    if (GetWorld())
    {
        GetWorld()->GetTimerManager().ClearTimer(UpdateTimerHandle);
        GetWorld()->GetTimerManager().ClearTimer(PlayersTimerHandle);
    }
    
    // Reset state
    bIsConnected = false;
    SessionID.Empty();
    OnlinePlayers.Empty();
    
    LogServerMessage(TEXT("✅ Disconnected from MMO server"));
}

void AGameServerManager::UpdatePlayerPosition(const FVector& Position, const FRotator& Rotation)
{
    if (!bIsConnected)
    {
        return;
    }
    
    // Update local player data
    LocalPlayerData.Position = Position;
    LocalPlayerData.Rotation = Rotation;
    
    // Create HTTP request
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = HttpModule->CreateRequest();
    Request->OnProcessRequestComplete().BindUObject(this, &AGameServerManager::OnUpdateResponse);
    Request->SetURL(ServerURL + TEXT("/game/session/") + SessionID + TEXT("/update"));
    Request->SetVerb(TEXT("PUT"));
    Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
    Request->SetContentAsString(CreateUpdatePayload());
    Request->ProcessRequest();
}

void AGameServerManager::UpdatePlayerStats(int32 Health, int32 Level, int32 Score, int32 Experience)
{
    if (!bIsConnected)
    {
        return;
    }
    
    // Update local player data
    LocalPlayerData.Health = Health;
    LocalPlayerData.Level = Level;
    LocalPlayerData.Score = Score;
    LocalPlayerData.Experience = Experience;
    
    // Create HTTP request
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = HttpModule->CreateRequest();
    Request->OnProcessRequestComplete().BindUObject(this, &AGameServerManager::OnUpdateResponse);
    Request->SetURL(ServerURL + TEXT("/game/session/") + SessionID + TEXT("/update"));
    Request->SetVerb(TEXT("PUT"));
    Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
    Request->SetContentAsString(CreateUpdatePayload());
    Request->ProcessRequest();
}

void AGameServerManager::RequestOnlinePlayers()
{
    if (!bIsConnected)
    {
        return;
    }
    
    // Create HTTP request
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = HttpModule->CreateRequest();
    Request->OnProcessRequestComplete().BindUObject(this, &AGameServerManager::OnPlayersResponse);
    Request->SetURL(ServerURL + TEXT("/game/players"));
    Request->SetVerb(TEXT("GET"));
    Request->ProcessRequest();
}

void AGameServerManager::OnConnectResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
    if (!bWasSuccessful || !Response.IsValid())
    {
        LogServerMessage(TEXT("❌ Failed to connect to MMO server: Network error"), true);
        OnServerError.Broadcast(TEXT("Network connection failed"));
        return;
    }
    
    int32 ResponseCode = Response->GetResponseCode();
    FString ResponseContent = Response->GetContentAsString();
    
    if (ResponseCode == 200 || ResponseCode == 201)
    {
        // Parse JSON response
        TSharedPtr<FJsonObject> JsonObject;
        TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseContent);
        
        if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
        {
            // Extract session ID
            if (JsonObject->HasField(TEXT("session_id")))
            {
                SessionID = JsonObject->GetStringField(TEXT("session_id"));
                bIsConnected = true;
                
                LogServerMessage(FString::Printf(TEXT("✅ Connected! Session ID: %s"), *SessionID));
                OnServerConnected.Broadcast(SessionID);
                
                // Start periodic updates
                if (GetWorld())
                {
                    GetWorld()->GetTimerManager().SetTimer(UpdateTimerHandle, [this]()
                    {
                        UpdatePlayerPosition(LocalPlayerData.Position, LocalPlayerData.Rotation);
                    }, UpdateInterval, true);
                    
                    GetWorld()->GetTimerManager().SetTimer(PlayersTimerHandle, [this]()
                    {
                        RequestOnlinePlayers();
                    }, 10.0f, true);
                }
            }
            else
            {
                LogServerMessage(TEXT("❌ Server response missing session_id"), true);
                OnServerError.Broadcast(TEXT("Invalid server response"));
            }
        }
        else
        {
            LogServerMessage(TEXT("❌ Failed to parse server response"), true);
            OnServerError.Broadcast(TEXT("Invalid JSON response"));
        }
    }
    else
    {
        LogServerMessage(FString::Printf(TEXT("❌ Server error: %d - %s"), ResponseCode, *ResponseContent), true);
        OnServerError.Broadcast(FString::Printf(TEXT("Server error: %d"), ResponseCode));
    }
}

void AGameServerManager::OnUpdateResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
    if (!bWasSuccessful || !Response.IsValid())
    {
        LogServerMessage(TEXT("⚠️ Failed to update player data"), true);
        return;
    }
    
    int32 ResponseCode = Response->GetResponseCode();
    if (ResponseCode == 200)
    {
        UE_LOG(LogTemp, VeryVerbose, TEXT("📍 Player data updated successfully"));
    }
    else
    {
        LogServerMessage(FString::Printf(TEXT("⚠️ Update failed: %d"), ResponseCode), true);
    }
}

void AGameServerManager::OnPlayersResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
    if (!bWasSuccessful || !Response.IsValid())
    {
        return;
    }
    
    int32 ResponseCode = Response->GetResponseCode();
    if (ResponseCode != 200)
    {
        return;
    }
    
    FString ResponseContent = Response->GetContentAsString();
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseContent);
    
    if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
    {
        // Clear current players
        OnlinePlayers.Empty();
        
        // Parse players array
        if (JsonObject->HasField(TEXT("players")))
        {
            const TArray<TSharedPtr<FJsonValue>>* PlayersArray;
            if (JsonObject->TryGetArrayField(TEXT("players"), PlayersArray))
            {
                for (const TSharedPtr<FJsonValue>& PlayerValue : *PlayersArray)
                {
                    TSharedPtr<FJsonObject> PlayerObject = PlayerValue->AsObject();
                    if (PlayerObject.IsValid())
                    {
                        FPlayerData PlayerData;
                        ParsePlayerData(PlayerObject, PlayerData);
                        OnlinePlayers.Add(PlayerData);
                    }
                }
            }
        }
        
        // Get player count
        int32 PlayerCount = 0;
        if (JsonObject->HasField(TEXT("count")))
        {
            PlayerCount = JsonObject->GetIntegerField(TEXT("count"));
        }
        
        UE_LOG(LogTemp, VeryVerbose, TEXT("👥 Online players updated: %d"), PlayerCount);
        OnPlayersUpdated.Broadcast(PlayerCount);
    }
}

FString AGameServerManager::CreateUpdatePayload() const
{
    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetNumberField(TEXT("x"), LocalPlayerData.Position.X);
    JsonObject->SetNumberField(TEXT("y"), LocalPlayerData.Position.Y);
    JsonObject->SetNumberField(TEXT("z"), LocalPlayerData.Position.Z);
    JsonObject->SetNumberField(TEXT("health"), LocalPlayerData.Health);
    JsonObject->SetNumberField(TEXT("level"), LocalPlayerData.Level);
    JsonObject->SetNumberField(TEXT("score"), LocalPlayerData.Score);
    JsonObject->SetNumberField(TEXT("experience"), LocalPlayerData.Experience);
    
    FString OutputString;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&OutputString);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);
    
    return OutputString;
}

void AGameServerManager::ParsePlayerData(const TSharedPtr<FJsonObject>& JsonObject, FPlayerData& OutPlayerData)
{
    if (!JsonObject.IsValid())
    {
        return;
    }
    
    if (JsonObject->HasField(TEXT("session_id")))
    {
        OutPlayerData.SessionID = JsonObject->GetStringField(TEXT("session_id"));
    }
    
    if (JsonObject->HasField(TEXT("x")))
    {
        OutPlayerData.Position.X = JsonObject->GetNumberField(TEXT("x"));
    }
    
    if (JsonObject->HasField(TEXT("y")))
    {
        OutPlayerData.Position.Y = JsonObject->GetNumberField(TEXT("y"));
    }
    
    if (JsonObject->HasField(TEXT("z")))
    {
        OutPlayerData.Position.Z = JsonObject->GetNumberField(TEXT("z"));
    }
    
    if (JsonObject->HasField(TEXT("health")))
    {
        OutPlayerData.Health = JsonObject->GetIntegerField(TEXT("health"));
    }
    
    if (JsonObject->HasField(TEXT("level")))
    {
        OutPlayerData.Level = JsonObject->GetIntegerField(TEXT("level"));
    }
    
    if (JsonObject->HasField(TEXT("score")))
    {
        OutPlayerData.Score = JsonObject->GetIntegerField(TEXT("score"));
    }
    
    if (JsonObject->HasField(TEXT("experience")))
    {
        OutPlayerData.Experience = JsonObject->GetIntegerField(TEXT("experience"));
    }
}

void AGameServerManager::LogServerMessage(const FString& Message, bool bIsError)
{
    if (bIsError)
    {
        UE_LOG(LogTemp, Error, TEXT("%s"), *Message);
        
        // Also show on screen for visibility
        if (GEngine)
        {
            GEngine->AddOnScreenDebugMessage(-1, 10.0f, FColor::Red, Message);
        }
    }
    else
    {
        UE_LOG(LogTemp, Log, TEXT("%s"), *Message);
        
        // Show success messages on screen too
        if (GEngine)
        {
            GEngine->AddOnScreenDebugMessage(-1, 5.0f, FColor::Green, Message);
        }
    }
}