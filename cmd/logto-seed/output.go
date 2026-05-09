package main

import (
	"context"
	"fmt"
	"log/slog"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

// publishSecrets writes collected secrets either as a K8s Secret or to stdout.
func publishSecrets(secrets map[string]string, cfg config) {
	if len(secrets) == 0 {
		return
	}

	if cfg.KubeNamespace != "" && cfg.KubeSecretName != "" {
		publishToK8s(secrets, cfg)
	} else {
		fmt.Println("--- logto-seed secrets ---")
		for k, v := range secrets {
			fmt.Printf("%s=%s\n", k, v)
		}
		fmt.Println("---")
	}
}

func publishToK8s(secrets map[string]string, cfg config) {
	slog.Info("Creating K8s secret", "namespace", cfg.KubeNamespace, "name", cfg.KubeSecretName)

	rules := clientcmd.NewDefaultClientConfigLoadingRules()
	overrides := &clientcmd.ConfigOverrides{}
	if cfg.KubeAPIServer != "" {
		overrides.ClusterInfo.Server = cfg.KubeAPIServer
	}
	kubeConfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(rules, overrides)
	restCfg, err := kubeConfig.ClientConfig()
	if err != nil {
		fatal("Failed to load kubeconfig", "error", err)
	}

	clientset, err := kubernetes.NewForConfig(restCfg)
	if err != nil {
		fatal("Failed to create K8s client", "error", err)
	}

	data := make(map[string][]byte, len(secrets))
	for k, v := range secrets {
		data[k] = []byte(v)
	}

	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cfg.KubeSecretName,
			Namespace: cfg.KubeNamespace,
		},
		Data: data,
	}

	secretsClient := clientset.CoreV1().Secrets(cfg.KubeNamespace)
	existing, err := secretsClient.Get(context.Background(), cfg.KubeSecretName, metav1.GetOptions{})
	if err == nil {
		if existing.Data == nil {
			existing.Data = make(map[string][]byte)
		}
		for k, v := range data {
			existing.Data[k] = v
		}
		if _, err := secretsClient.Update(context.Background(), existing, metav1.UpdateOptions{}); err != nil {
			fatal("Failed to update K8s secret", "error", err)
		}
		slog.Info("Updated K8s secret")
	} else {
		if _, err := secretsClient.Create(context.Background(), secret, metav1.CreateOptions{}); err != nil {
			fatal("Failed to create K8s secret", "error", err)
		}
		slog.Info("Created K8s secret")
	}
}
