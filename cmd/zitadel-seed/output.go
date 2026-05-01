package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func fatal(msg string, args ...any) {
	slog.Error(msg, args...)
	os.Exit(1)
}

// secretStore collects key-value pairs during the seed run and
// publishes them at the end — either as a K8s Secret or to stdout.
type secretStore struct {
	entries map[string]string
	order   []string // preserve insertion order for deterministic stdout
}

func newSecretStore() *secretStore {
	return &secretStore{entries: make(map[string]string)}
}

func (ss *secretStore) set(name, value string) {
	if _, exists := ss.entries[name]; !exists {
		ss.order = append(ss.order, name)
	}
	ss.entries[name] = value
}

// publish writes the collected secrets. If kubeconfig/namespace/secret name
// are configured it creates a K8s Secret; otherwise it prints to stdout.
func (ss *secretStore) publish(cfg config) {
	if len(ss.entries) == 0 {
		return
	}

	if cfg.KubeNamespace != "" && cfg.KubeSecretName != "" {
		ss.publishToK8s(cfg)
	} else {
		ss.publishToStdout()
	}
}

func (ss *secretStore) publishToStdout() {
	fmt.Println("--- zitadel-seed secrets ---")
	for _, k := range ss.order {
		fmt.Printf("%s=%s\n", k, ss.entries[k])
	}
	fmt.Println("---")
}

func (ss *secretStore) publishToK8s(cfg config) {
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

	data := make(map[string][]byte, len(ss.entries))
	for k, v := range ss.entries {
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
		existing.Data = data
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
