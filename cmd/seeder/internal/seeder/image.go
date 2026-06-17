package seeder

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	imagev1 "github.com/Sokol111/ecommerce-image-service-api/gen/connect/image/v1"
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

	if err := s.uploadToStorage(ctx, presign.UploadUrl, content, imageFile); err != nil {
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

func detectContentType(filename string) (imagev1.ImageContentType, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	switch ext {
	case ".jpg", ".jpeg":
		return imagev1.ImageContentType_IMAGE_CONTENT_TYPE_JPEG, nil
	case ".png":
		return imagev1.ImageContentType_IMAGE_CONTENT_TYPE_PNG, nil
	case ".webp":
		return imagev1.ImageContentType_IMAGE_CONTENT_TYPE_WEBP, nil
	case ".avif":
		return imagev1.ImageContentType_IMAGE_CONTENT_TYPE_AVIF, nil
	default:
		return imagev1.ImageContentType_IMAGE_CONTENT_TYPE_UNSPECIFIED, fmt.Errorf("unsupported image format: %s", ext)
	}
}

func (s *Seeder) createPresignURL(ctx context.Context, filename string, size int) (*imagev1.CreatePresignResponse, error) {
	contentType, err := detectContentType(filename)
	if err != nil {
		return nil, err
	}

	req := &imagev1.CreatePresignRequest{
		OwnerType:   imagev1.OwnerType_OWNER_TYPE_DRAFT,
		OwnerId:     fmt.Sprintf("seed_%s", time.Now().Format("20060102150405")),
		Filename:    filename,
		ContentType: contentType,
		Size:        int64(size),
		Role:        imagev1.ImageRole_IMAGE_ROLE_MAIN,
	}

	return s.imageClient.CreatePresign(s.outgoingCtx(ctx), req)
}

func (s *Seeder) uploadToStorage(ctx context.Context, uploadURL string, content []byte, filename string) error {
	mimeType, err := detectMimeType(filename)
	if err != nil {
		return err
	}

	parsedURL, err := url.Parse(uploadURL)
	if err != nil {
		return fmt.Errorf("failed to parse upload URL: %w", err)
	}

	targetURL, hostHeader := s.resolveUploadURL(*parsedURL)

	req, err := http.NewRequestWithContext(ctx, "PUT", targetURL, bytes.NewReader(content))
	if err != nil {
		return fmt.Errorf("failed to create upload request: %w", err)
	}
	req.Header.Set("Content-Type", mimeType)
	req.ContentLength = int64(len(content))
	req.Host = hostHeader

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

// resolveUploadURL returns the actual URL to connect to and the Host header value.
// When storageHostOverride is set, TCP goes to the override but Host header
// preserves the original value so the S3 signature remains valid.
func (s *Seeder) resolveUploadURL(u url.URL) (targetURL, hostHeader string) {
	hostHeader = u.Host
	if s.storageHostOverride != "" {
		u.Host = s.storageHostOverride
	}
	return u.String(), hostHeader
}

func detectMimeType(filename string) (string, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg", nil
	case ".png":
		return "image/png", nil
	case ".webp":
		return "image/webp", nil
	case ".avif":
		return "image/avif", nil
	default:
		return "", fmt.Errorf("unsupported image format: %s", ext)
	}
}

func (s *Seeder) confirmUpload(ctx context.Context, uploadToken, altText string) (string, error) {
	req := &imagev1.ConfirmUploadRequest{
		UploadToken: uploadToken,
		Alt:         altText,
		Role:        imagev1.ImageRole_IMAGE_ROLE_MAIN,
	}

	resp, err := s.imageClient.ConfirmUpload(s.outgoingCtx(ctx), req)
	if err != nil {
		return "", fmt.Errorf("failed to confirm upload: %w", err)
	}

	return resp.Image.GetId(), nil
}
