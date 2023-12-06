#!/usr/bin/env bash
export TMC_CLI_TOKEN='Pt0KfLuVHXOAYJRPKTH0BvnS-re6kvHrpsqPdwnhBxVO2RaT39HDkmbxT2z0vGwl'
export TMC_CLUSTER_GROUP='netc-jcac-course-clusters'
export TMC_MGMT_CLUSTER='netc-jcac-courses-mgmt-cluster'

create_clusters_for_courses() {
  local courses="A-531-1900-JCAC
A-531-4426-H30A-ICAC
A-531-4415-H31A-DISCO
A-531-4417-H32A-CTE"
  while read -r course
  do
    cluster_name="cluster-$course"
    cluster_group=$TMC_CLUSTER_GROUP
    data_values="Name: $(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')
ClusterGroup: $cluster_group
ManagementClusterName: $TMC_MGMT_CLUSTER
ProvisionerName: tmc-ns
Version: v1.23.8+vmware.2-tkg.2-zshippable
ClusterClass: tanzukubernetescluster
ControlPlaneReplicas: 1
ControlPlaneOsName: photon
ControlPlaneOsArch: amd64
ControlPlaneOsVersion: 3
NodePoolName: cluster-${course}-np-0
NodePoolClass: node-pool
NodePoolReplicas: 1
NodePoolOsName: photon
NodePoolOsArch: amd64
NodePoolOsVersion: 3
PodsCidrBlocks: 172.20.0.0/16
ServiceCidrBlocks: 10.96.0.0/16
StorageClass: vc01cl01-t0compute
VmClass: guaranteed-xlarge"
    echo "===> Creating cluster $cluster_name, values: 
$data_values"
    cmd=(tanzu mission-control cluster create -t tanzukubernetescluster-supervisor \
      -v <(echo "$data_values"))
    echo "Command: ${cmd[*]}"
  done <<< "$courses"
}

create_namespaces_for_students() {
  local courses="A-531-1900-JCAC
A-531-4426-H30A-ICAC
A-531-4415-H31A-DISCO
A-531-4417-H32A-CTE"
  local students="Sally Ride
Bobby Flay
Guy Fieri
Melissa McCarthy
Jason Belmonte"
  while read -r course
  do
    cluster_name="cluster-$course"
    while read -r student
    do
      workspace_name="wksp-$namespace_name"
      workspace_data_values="Name: $workspace_name
Description: Workspace for student '$student' in course '$course'"
      echo "===> Creating workspace '$workspace_name', values: 
$workspace_data_values"
      wksp_cmd=(tanzu mission-control workspace create -v <(echo "$workspace_data_values"))
      echo "${wksp_cmd[*]}"
      namespace_name="ns-$(echo "$student" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
      namespace_data_values="ClusterName: $cluster_name
Name: $namespace_name
ManagementClusterName: $TMC_MGMT_CLUSTER
ProvisionerName: tmc-ns"
      echo "===> Creating namespace '$namespace_name', values: 
$namespace_data_values"
      ns_cmd=(tanzu mission-control cluster namespace create -v <(echo "$namespace_data_values"))
      echo "${ns_cmd[*]}"
    done <<< "$students"
  done <<< "$courses"
}
# Example course names taken from the Cryptologic Technician - Networks LaDR
# https://www.cool.osd.mil/usn/LaDR/ctn_e1.pdf

create_clusters_for_courses &&
  create_namespaces_for_students
  # apply_policies_to_namespaces "$students"
