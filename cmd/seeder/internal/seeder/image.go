package seeder

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	imageapi "github.com/Sokol111/ecommerce-image-service-api/gen/httpapi"
)

func (s *Seeder) uploadImage(ctx context.Context, imageFile, altText string) (string, error) {
	imagePath := filepath.Join(s.assetsDir, imageFile)

	content, size, err := readFile(imagePath)
	if err != nil {
		return "", err
	}

	presign, err := s.createPresignURL(ctx, imageFile, size)
	if err != nil {
		return "", err
	}

	if err := s.uploadToStorage(ctx, presign, content, imageFile); err != nil {
		return "", err
	}

	return s.confirmUpload(ctx, presign.UploadToken, altText)
}

func readFile(path string) ([]byte, int, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, 0, fmt.Errorf("image file not found: %s", path)
	}

	content, err := os.ReadFile(path)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to read image file: %w", err)
	}

	return content, int(info.Size()), nil
}

func detectContentType(filename string) (imageapi.PresignRequestContentType, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	switch ext {
	case ".jpg", ".jpeg":
		return imageapi.PresignRequestContentTypeImageJpeg, nil
	case ".png":
		return imageapi.PresignRequestContentTypeImagePNG, nil
	case ".webp":
		return imageapi.PresignRequestContentTypeImageWEBP, nil
	case ".avif":
		return imageapi.PresignRequestContentTypeImageAvif, nil
	default:
		return "", fmt.Errorf("unsupported image format: %s", ext)
	}
}

func (s *Seeder) createPresignURL(ctx context.Context, filename string, size int) (*imageapi.PresignResponse, error) {
	contentType, err := detectContentType(filename)
	if err != nil {
		return nil, err
	}

	req := &imageapi.PresignRequest{
		OwnerType:   imageapi.OwnerTypeDraft,
		OwnerId:     fmt.Sprintf("seed_%s", time.Now().Format("20060102150405")),
		Filename:    filename,
		ContentType: contentType,
		Size:        size,
		Role:        imageapi.ImageRoleMain,
	}

	resp, err := s.imageClient.CreatePresign(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to get presigned URL: %w", err)
	}

	presign, ok := resp.(*imageapi.PresignResponse)
	if !ok {
		return nil, fmt.Errorf("presign failed: unexpected response type %T", resp)
	}

	return presign, nil
}

func (s *Seeder) uploadToStorage(ctx context.Context, presign *imageapi.PresignResponse, content []byte, filename string) error {
	body, contentType, err := buildMultipartBody(presign.FormData, content, filename)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", presign.UploadUrl.String(), body)
	if err != nil {
		return fmt.Errorf("failed to create upload request: %w", err)
	}
	req.Header.Set("Content-Type", contentType)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to upload image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}

func buildMultipartBody(formData map[string]string, content []byte, filename string) (*bytes.Buffer, string, error) {
	var buf bytes.Buffer
	writer := multipart.NewWriter(&buf)

	for key, value := range formData {
		if err := writer.WriteField(key, value); err != nil {
			return nil, "", fmt.Errorf("failed to write form field %s: %w", key, err)
		}
	}

	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create form file: %w", err)
	}
	if _, err = part.Write(content); err != nil {
		return nil, "", fmt.Errorf("failed to write file content: %w", err)
	}
	writer.Close()

	return &buf, writer.FormDataContentType(), nil
}

func (s *Seeder) confirmUpload(ctx context.Context, uploadToken, altText string) (string, error) {
	req := &imageapi.ConfirmRequest{
		UploadToken: uploadToken,
		Alt:         altText,
		Role:        imageapi.ImageRoleMain,
	}

	resp, err := s.imageClient.ConfirmUpload(ctx, req)
	if err != nil {
		return "", fmt.Errorf("failed to confirm upload: %w", err)
	}

	image, ok := resp.(*imageapi.Image)
	if !ok {
		return "", fmt.Errorf("confirm failed: unexpected response type %T", resp)
	}

	return image.ID, nil
}
