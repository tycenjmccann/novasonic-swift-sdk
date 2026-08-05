//
//  ContentView.swift
//  PackageTester
//
//  Created by McCann, Tycen on 7/19/25.
//

import SwiftUI
import NovaSonicCore
import NovaSonicUI

struct ContentView: View {
    @State private var heartColor: Color = .red
    @StateObject private var floatingButtonStreamManager = NovaSonicStreamManager()
    @StateObject private var chatViewStreamManager = NovaSonicStreamManager()
    @State private var launchSonic = false

    
    var body: some View {
        VStack(spacing: 20) {
            Text("Nova Sonic Demo")
                .font(.title2).bold()

            Image(systemName: "heart.fill")
                .font(.system(size: 180))
                .foregroundColor(heartColor)

            Spacer()
            
            // Nova Sonic configuration
            NovaSonicFloatingButton(
                streamManager: floatingButtonStreamManager,
                voice: .carlos,                // Options: .matthew, .tiffany, .amy, .carlos, .lupe
                temperature: 0.8,               // Controls creativity (0.1-1.0)
                topP: 0.9,                      // Controls diversity (0.5-1.0)
                maxTokens: 1024,                // Max response length
                systemPrompt: "You are a helpful assistant with tools to change the color of a heart.",
                inputSampleRate: .rate16kHz,    // Options: .rate8kHz, .rate16kHz, .rate24kHz
                outputSampleRate: .rate24kHz,   // Options: .rate8kHz, .rate16kHz, .rate24kHz
                endpointingSensitivity: .high,
                enableDynamoDBHistory: true,
                dynamoDBTableName: "nova_sonic_chat_history",
                dynamoDBUserId: "user123",
                dynamoDBRegion: "us-east-1",
                //awsCredentialIdentityResolver: myCredentialResolver,
                logLevel: .standard,            // Options: .verbose, .standard, .minimal, .none
                tools: [ChangeMyHeartTool.self],     // Custom tools to register
                position: .bottomLeft,         // Options: .topLeft, .topRight, .bottomLeft, .bottomRight
                speakFirst: false,              // Whether Nova Sonic speaks first
                onStateChange: { isStreaming in
                    // Handle streaming state changes
                }
            )
            
            VStack(spacing: 10) {
                Button(action: {
                    launchSonic = true
                }) {
                    Text("My Button")
                }
                .buttonStyle(.borderedProminent)
            }
            
        }
        .padding()
        .onAppear{
            setupHeartColorCallback()
        }
        .sheet(isPresented: $launchSonic) {
        // Nova Sonic configuration
        NovaSonicChatView(
            streamManager: chatViewStreamManager,
            voice: .lupe,                // Options: .matthew, .tiffany, .amy, .carlos, .lupe
            systemPrompt: "You are a helpful assistant with tools to change the color of a heart.",
            endpointingSensitivity: .low, //Nova 2.0
            enableParalinguisticDetection: true,
            initialTextPrompt: "Hey, I'm Tycen",
            enableDynamoDBHistory: true,
            dynamoDBTableName: "nova_sonic_chat_history",
            dynamoDBUserId: "user123",
            dynamoDBRegion: "us-east-1",
            tools: [ChangeMyHeartTool.self],   // Custom tools to register
            showConversationHistory: true,
            speakFirst: false

        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }


    }
    // Set up heart color change callback
    private func setupHeartColorCallback() {
        ChangeMyHeartTool.onColorChange = { color in
            DispatchQueue.main.async {
                heartColor = color
            }
        }
    }
    
    
}

#Preview {
    ContentView()
}
