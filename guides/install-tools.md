# Create the clusters

In this guide, we're going to create two clusters:

- A "shared services" cluster that will run Harbor and Keycloak (an
  identity management tool), and
- A cluster dedicated to Tanzu Mission Control.

> ⚠️  At this time, it is not possible to install TMC Self Managed on a
> Kubernetes cluster that has Contour already installed. This is why
> we are using two clusters instead of one.
>
> This guide will use a single cluster once this limitation is lifted.


