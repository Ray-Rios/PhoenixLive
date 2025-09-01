#include "GameServerManager.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "Engine/World.h"
#include "TimerManager.h"

AGameServerManager::AGameServerManager()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = true;
    
    // Initialize HTTP Module
    HttpModule = &FHttpModule::Get();
}

void AGameServerManager::BeginPlay()
{
    Super::BeginPlay();
    
    LogServerMessage(TEXT("🎮 MMO Game Server Manager Started"));
    LogServerMessage(FString::Printf(TEXT("🌐 Server URL: %s"), *ServerURL));
    
    // Auto-connect to server on start
    ConnectToServer();
}

void AGameServerManager::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    // Clean up timers
    if (GetWorld())
    {
        GetWorld()->GetTimerManager().ClearTimer(UpdateTimerHandle);
        GetWorld()->GetTimerManager().ClearTimer(PlayersTimerHandle);
    }
    
    // Disconnect from server
    if (bIsConnected)
    {
        DisconnectFromServer();
    }
    
    Super::EndPlay(EndPlayReason);
}

void AGameServerManager::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);
    
    // Update local player data from pawn if available
    if (APawn* PlayerPawn = GetWorld()->GetFirstPlayerController()->GetPawn())
    {
        LocalPlayerData.Position = PlayerPawn->GetActorLocation();
        LocalPlayerData.Rotation = PlayerPawn->GetActorRotation();
    }
}

void AGameServerManager::ConnectToServer()
{
    if (bIsConnected)
    {
        LogServerMessage(TEXT("⚠️ Already connected to server"));
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
    JsonObject->SetStringField(TEXT("user_id"), PlayerID);
    
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
    
    LogServerMessage(TEXT("✅ Disconnected from server"));
}

void AGameServerManager::UpdatePlayerPosition(const FVector& Position, const FRotator& Rotation)
{
    LocalPlayerData.Position = Position;
    LocalPlayerData.Rotation = Rotation;
    
    // The automatic update will send this data
}

void AGameServerManager::UpdatePlayerStats(int32 Health, int32 Level, int32 Score, int32 Experience)
{
    LocalPlayerData.Health = Health;
    LocalPlayerData.Level = Level;
    LocalPlayerData.Score = Score;
    LocalPlayerData.Experience = Experience;
    
    // The automatic update will send this data
}

void AGameServerManager::RequestOnlinePlayers()
{
    if (!bIsConnected)
    {
        LogServerMessage(TEXT("⚠️ Not connected to server"), true);
        return;
    }
    
    // Create HTTP request
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = HttpModule->CreateRequest();
    Request->OnProcessRequestComplete().BindUObject(this, &AGameServerManager::OnPlayersResponse);
    Request->SetURL(ServerURL + TEXT("/game/players"));
    Request->SetVerb(TEXT("GET"));
    Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
    Request->ProcessRequest();
}

void AGameServerManager::OnConnectResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
    if (!bWasSuccessful || !Response.IsValid())
    {
        LogServerMessage(TEXT("❌ Failed to connect to server"), true);
        OnServerError.Broadcast(TEXT("Connection failed"));
        return;
    }
    
    if (Response->GetResponseCode() != 200)
    {
        LogServerMessage(FString::Printf(TEXT("❌ Server error: %d"), Response->GetResponseCode()), true);
        OnServerError.Broadcast(FString::Printf(TEXT("Server error: %d"), Response->GetResponseCode()));
        return;
    }
    
    // Parse response
    FString ResponseString = Response->GetContentAsString();
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseString);
    
    if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
    {
        // Extract session data
        SessionID = JsonObject->GetStringField(TEXT("id"));
        LocalPlayerData.SessionID = SessionID;
        
        // Update local player data from response
        ParsePlayerData(JsonObject, LocalPlayerData);
        
        bIsConnected = true;
        
        LogServerMessage(FString::Printf(TEXT("✅ Connected! Session ID: %s"), *SessionID));
        OnServerConnected.Broadcast(SessionID);
        
        // Start automatic updates
        if (GetWorld())
        {
            GetWorld()->GetTimerManager().SetTimer(UpdateTimerHandle, [this]()
            {
                if (bIsConnected && !SessionID.IsEmpty())
                {
                    // Send player update
                    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> UpdateRequest = HttpModule->CreateRequest();
                    UpdateRequest->OnProcessRequestComplete().BindUObject(this, &AGameServerManager::OnUpdateResponse);
                    UpdateRequest->SetURL(ServerURL + TEXT("/game/session/") + SessionID + TEXT("/update"));
                    UpdateRequest->SetVerb(TEXT("PUT"));
                    UpdateRequest->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
                    UpdateRequest->SetContentAsString(CreateUpdatePayload());
                    UpdateRequest->ProcessRequest();
                }
            }, UpdateInterval, true);
            
            // Start player list updates
            GetWorld()->GetTimerManager().SetTimer(PlayersTimerHandle, [this]()
            {
                RequestOnlinePlayers();
            }, UpdateInterval * 2.0f, true);
        }
    }
    else
    {
        LogServerMessage(TEXT("❌ Invalid response from server"), true);
        OnServerError.Broadcast(TEXT("Invalid server response"));
    }
}

void AGameServerManager::OnUpdateResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
    if (!bWasSuccessful || !Response.IsValid() || Response->GetResponseCode() != 200)
    {
        LogServerMessage(TEXT("⚠️ Failed to update player data"), true);
        return;
    }
    
    // Optionally parse updated data from server
    FString ResponseString = Response->GetContentAsString();
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseString);
    
    if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
    {
        ParsePlayerData(JsonObject, LocalPlayerData);
    }
}

void AGameServerManager::OnPlayersResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
{
    if (!bWasSuccessful || !Response.IsValid() || Response->GetResponseCode() != 200)
    {
        LogServerMessage(TEXT("⚠️ Failed to get online players"), true);
        return;
    }
    
    FString ResponseString = Response->GetContentAsString();
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseString);
    
    if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
    {
        int32 PlayerCount = JsonObject->GetIntegerField(TEXT("count"));
        const TArray<TSharedPtr<FJsonValue>>* PlayersArray;
        
        if (JsonObject->TryGetArrayField(TEXT("players"), PlayersArray))
        {
            OnlinePlayers.Empty();
            
            for (const TSharedPtr<FJsonValue>& PlayerValue : *PlayersArray)
            {
                if (PlayerValue->Type == EJson::Object)
                {
                    TSharedPtr<FJsonObject> PlayerObj = PlayerValue->AsObject();
                    FPlayerData PlayerData;
                    ParsePlayerData(PlayerObj, PlayerData);
                    OnlinePlayers.Add(PlayerData);
                }
            }
            
            LogServerMessage(FString::Printf(TEXT("👥 Online Players: %d"), PlayerCount));
            OnPlayersUpdated.Broadcast(PlayerCount);
        }
    }
}

FString AGameServerManager::CreateUpdatePayload() const
{
    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    
    JsonObject->SetNumberField(TEXT("player_x"), LocalPlayerData.Position.X);
    JsonObject->SetNumberField(TEXT("player_y"), LocalPlayerData.Position.Y);
    JsonObject->SetNumberField(TEXT("player_z"), LocalPlayerData.Position.Z);
    JsonObject->SetNumberField(TEXT("rotation_x"), LocalPlayerData.Rotation.Roll);
    JsonObject->SetNumberField(TEXT("rotation_y"), LocalPlayerData.Rotation.Pitch);
    JsonObject->SetNumberField(TEXT("rotation_z"), LocalPlayerData.Rotation.Yaw);
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
    
    OutPlayerData.SessionID = JsonObject->GetStringField(TEXT("id"));
    OutPlayerData.Position.X = JsonObject->GetNumberField(TEXT("player_x"));
    OutPlayerData.Position.Y = JsonObject->GetNumberField(TEXT("player_y"));
    OutPlayerData.Position.Z = JsonObject->GetNumberField(TEXT("player_z"));
    OutPlayerData.Rotation.Roll = JsonObject->GetNumberField(TEXT("rotation_x"));
    OutPlayerData.Rotation.Pitch = JsonObject->GetNumberField(TEXT("rotation_y"));
    OutPlayerData.Rotation.Yaw = JsonObject->GetNumberField(TEXT("rotation_z"));
    OutPlayerData.Health = JsonObject->GetIntegerField(TEXT("health"));
    OutPlayerData.Level = JsonObject->GetIntegerField(TEXT("level"));
    OutPlayerData.Score = JsonObject->GetIntegerField(TEXT("score"));
    OutPlayerData.Experience = JsonObject->GetIntegerField(TEXT("experience"));
}

void AGameServerManager::LogServerMessage(const FString& Message, bool bIsError)
{
    if (bIsError)
    {
        UE_LOG(LogTemp, Error, TEXT("[MMO Server] %s"), *Message);
    }
    else
    {
        UE_LOG(LogTemp, Log, TEXT("[MMO Server] %s"), *Message);
    }
    
    // Also print to screen for debugging
    if (GEngine)
    {
        FColor Color = bIsError ? FColor::Red : FColor::Green;
        GEngine->AddOnScreenDebugMessage(-1, 5.0f, Color, FString::Printf(TEXT("[MMO] %s"), *Message));
    }
}