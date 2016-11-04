#cloud-boothook
bootcmd:
  - echo 'SERVER_ENVIRONMENT=${environment}' | sudo tee --append /etc/environment
  - echo 'SERVER_GROUP=${name}' | sudo tee --append /etc/environment
  - echo 'SERVER_REGION=${region}' | sudo tee --append /etc/environment

  - mkdir -p /etc/ecs
  - echo 'ECS_CLUSTER=${name}' | sudo tee --append /etc/ecs/ecs.config 
  - echo 'ECS_ENGINE_AUTH_TYPE=${docker_auth_type}' | sudo tee --append /etc/ecs/ecs.config 
  - echo 'ECS_ENGINE_AUTH_DATA=${docker_auth_data}' | sudo tee --append /etc/ecs/ecs.config 
