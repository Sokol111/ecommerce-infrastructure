package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	imageapi "github.com/Sokol111/ecommerce-image-service-api/gen/httpapi"
)

func (s *Seeder) uploadImage(imageFile, productName string) (string, error) {
	imagePath := filepath.Join(s.assetsDir, imageFile)

	fileInfo, err := os.Stat(imagePath)
	if err != nil {
		return "", fmt.Errorf("image file not found: %s", imagePath)
	}

	// Read file content
	fileContent, err := os.ReadFile(imagePath)
	if err != nil {
		return "", fmt.Errorf("failed to read image file: %w", err)
	}

	ctx := context.Background()

	// Determine content type using generated enum
	contentType := detectContentType(imageFile, fileContent)

	// Step 1: Get presigned URL
	presignReq := imageapi.CreatePresignJSONRequestBody{
		OwnerType:   imageapi.ProductDraft,
		OwnerId:     fmt.Sprintf("seed_%s", time.Now().Format("20060102150405")),
		Filename:    imageFile,
		ContentType: contentType,
		Size:        int(fileInfo.Size()),
		Role:        imageapi.Main,
	}

	presignResp, err := s.imageClient.CreatePresign(ctx, presignReq)
	if err != nil {
		return "", fmt.Errorf("failed to get presigned URL: %w", err)
	}
	defer presignResp.Body.Close()

	if presignResp.StatusCode >= 300 {
		body, _ := io.ReadAll(presignResp.Body)
		return "", fmt.Errorf("presign failed with status %d: %s", presignResp.StatusCode, string(body))
	}

	var presign imageapi.PresignResponse
	if err := json.NewDecoder(presignResp.Body).Decode(&presign); err != nil {
		return "", fmt.Errorf("failed to parse presign response: %w", err)
	}

	// Step 2: Upload to presigned URL
	uploadReq, err := http.NewRequest("PUT", presign.UploadUrl, bytes.NewReader(fileContent))
	if err != nil {
		return "", fmt.Errorf("failed to create upload request: %w", err)
	}

	for key, value := range presign.RequiredHeaders {
		uploadReq.Header.Set(key, value)
	}

	uploadResp, err := s.httpClient.Do(uploadReq)
	if err != nil {
		return "", fmt.Errorf("failed to upload image: %w", err)
	}
	defer uploadResp.Body.Close()

	if uploadResp.StatusCode >= 300 {
		body, _ := io.ReadAll(uploadResp.Body)
		return "", fmt.Errorf("upload failed with status %d: %s", uploadResp.StatusCode, string(body))
	}

	// Step 3: Confirm upload
	confirmReq := imageapi.ConfirmUploadJSONRequestBody{
		UploadToken: presign.UploadToken,
		Alt:         productName,
		Role:        imageapi.Main,
	}

	confirmResp, err := s.imageClient.ConfirmUpload(ctx, confirmReq)
	if err != nil {
		return "", fmt.Errorf("failed to confirm upload: %w", err)
	}
	defer confirmResp.Body.Close()

	if confirmResp.StatusCode >= 300 {
		body, _ := io.ReadAll(confirmResp.Body)
		return "", fmt.Errorf("confirm failed with status %d: %s", confirmResp.StatusCode, string(body))
	}

	var image imageapi.Image
	if err := json.NewDecoder(confirmResp.Body).Decode(&image); err != nil {
		return "", fmt.Errorf("failed to parse confirm response: %w", err)
	}

	return image.Id, nil
}

// detectContentType returns the appropriate content type enum based on file extension or content
func detectContentType(filename string, content []byte) imageapi.PresignRequestContentType {
	ext := filepath.Ext(filename)
	switch ext {
	case ".jpg", ".jpeg":
		return imageapi.Imagejpeg
	case ".png":
		return imageapi.Imagepng
	case ".webp":
		return imageapi.Imagewebp
	case ".avif":
		return imageapi.Imageavif
	}

	// Fallback to content detection
	mimeType := http.DetectContentType(content)
	switch mimeType {
	case "image/jpeg":
		return imageapi.Imagejpeg
	case "image/png":
		return imageapi.Imagepng
	case "image/webp":
		return imageapi.Imagewebp
	default:
		return imageapi.Imagejpeg
	}
}
