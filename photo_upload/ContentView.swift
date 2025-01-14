//
//  ContentView.swift
//  photo_upload
//
//  Created by Beyond_2 on 6/1/25.
//
import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var pickedImage: Image?
    @State private var imageUrl: String?
    
    var body: some View {
        VStack(spacing: 20) {
            PhotosPicker(
                selection: $selectedItem) {
                    if let image = pickedImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .frame(width: 200, height: 200)
                    } else {
                        Image(systemName: "person.circle")
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .frame(width: 200, height: 200)
                        
                    }
                }
                .onChange(of: selectedItem) {
                    Task {
                        if let selectedItem = selectedItem {
                            do {
                                let data = try await selectedItem.loadTransferable(type: Data.self)
                                if let data = data,
                                   let uiImage = UIImage(data: data) {
                                    pickedImage = Image(uiImage: uiImage)
                                    pickedImageData = data
                                    
                                }
                            } catch {
                                print("Error loading asset: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            
            if let imageUrl = imageUrl {
                Text("Image Uploaded!")
                Text(imageUrl)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let url = URL(string: imageUrl) {
                            UIApplication.shared.open(url)
                        }
                    }
            }
            
            Button(action: {
                if let imageData = pickedImageData {
                    uploadImage(imageData)
                } else {
                    print("No image selected now")
                }
            }) {
                Text("Upload Image")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(pickedImageData == nil)
        }
        .padding()
    }
    
    private func uploadImage(_ imageData: Data) {
        let apiKey = "6d207e02198a847aa98d0a2a901485a5"
        let url = URL(string: "https://freeimage.host/api/1/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add API key
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n")
        body.append("\(apiKey)\r\n")
        
        // Add action
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"action\"\r\n\r\n")
        body.append("upload\r\n")
        
        if let uiImage = UIImage(data: imageData) {
            var resizedData: Data?
            
            if imageData.count > 1 * 1024 * 1024 {
                if let resizedImage = resizeImage(uiImage, targetWidth: 800) {
                    resizedData = resizedImage.pngData()
                } else {
                    resizedData = imageData
                }
                
                // Only append if we have valid resized data
                if let validData = resizedData {
                    body.append("--\(boundary)\r\n")
                    body.append("Content-Disposition: form-data; name=\"source\"; filename=\"image.jpg\"\r\n")
                    body.append("Content-Type: image/jpeg\r\n\r\n")
                    body.append(validData)
                } else {
                    print("Error resizing image")
                    return
                }
            }
            
            body.append("\r\n")
            body.append("--\(boundary)--\r\n")
            
            request.httpBody = body
            
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received from upload")
                    return
                }
                
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let imageDict = jsonResponse["image"] as? [String: Any],
                       let displayUrl = imageDict["url_viewer"] as? String {
                        DispatchQueue.main.async  {
                            self.imageUrl = displayUrl
                        }
                    } else {
                        print("Invalid JSON response")
                    }
                } catch {
                    print("Error decoding JSON: \(error.localizedDescription)")
                }
            }.resume()
        }
        
        func resizeImage(_ image: UIImage, targetWidth: CGFloat) -> UIImage? {
            let scale = targetWidth / image.size.width
            let targetHeight = image.size.height * scale
            let size = CGSize(width: targetWidth, height: targetHeight)
            
            UIGraphicsBeginImageContext(size)
            image.draw(in: CGRect(origin: .zero, size: size))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage
        }
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
