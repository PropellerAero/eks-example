kind: Config
apiVersion: v1
preferences: {}
current-context: ${cluster_name}
clusters:
  - name: ${cluster_name}
    cluster:
      certificate-authority-data: ${ca_data}
      server: ${server}

contexts:
  - name: ${cluster_name}
    context:
      cluster: ${cluster_name}
      user: iam-user

users:
  - name: iam-user
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1alpha1
        env: null
        command: aws
        args:
          - eks
          - get-token
          - --cluster-name
          - ${cluster_name}
          ${role_arn != "" ? "- --role-arn" : ""}
          ${role_arn != "" ? "- ${role_arn}" : ""}