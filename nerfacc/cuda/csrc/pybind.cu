/*
 * Copyright (c) 2022 Ruilong Li, UC Berkeley.
 */

#include "include/helpers_cuda.h"
#include "include/helpers_math.h"
#include "include/helpers_contraction.h"


std::vector<torch::Tensor> ray_aabb_intersect(
    const torch::Tensor rays_o,
    const torch::Tensor rays_d,
    const torch::Tensor aabb);

std::vector<torch::Tensor> ray_marching(
    // rays
    const torch::Tensor rays_o,
    const torch::Tensor rays_d,
    const torch::Tensor t_min,
    const torch::Tensor t_max,
    // occupancy grid & contraction
    const torch::Tensor roi,
    const torch::Tensor grid_binary,
    const ContractionType type,
    // sampling
    const float step_size,
    const float cone_angle);

torch::Tensor unpack_info(
    const torch::Tensor packed_info, const int n_samples);

torch::Tensor unpack_info_to_mask(
    const torch::Tensor packed_info, const int n_samples);

torch::Tensor grid_query(
    const torch::Tensor samples,
    // occupancy grid & contraction
    const torch::Tensor roi,
    const torch::Tensor grid_value,
    const ContractionType type);

torch::Tensor contract(
    const torch::Tensor samples,
    // contraction
    const torch::Tensor roi,
    const ContractionType type);

torch::Tensor contract_inv(
    const torch::Tensor samples,
    // contraction
    const torch::Tensor roi,
    const ContractionType type);

torch::Tensor unpack_data(
    torch::Tensor packed_info,
    torch::Tensor data,
    int n_samples_per_ray,
    float pad_value);

// cub implementations: parallel across samples
bool is_cub_available() {
    return (bool) CUB_SUPPORTS_SCAN_BY_KEY();
}
torch::Tensor transmittance_from_sigma_forward_cub(
    torch::Tensor ray_indices,
    torch::Tensor starts,
    torch::Tensor ends,
    torch::Tensor sigmas);
torch::Tensor transmittance_from_sigma_backward_cub(
    torch::Tensor ray_indices,
    torch::Tensor starts,
    torch::Tensor ends,
    torch::Tensor transmittance,
    torch::Tensor transmittance_grad);
torch::Tensor transmittance_from_alpha_forward_cub(
    torch::Tensor ray_indices, torch::Tensor alphas);
torch::Tensor transmittance_from_alpha_backward_cub(
    torch::Tensor ray_indices,
    torch::Tensor alphas,
    torch::Tensor transmittance,
    torch::Tensor transmittance_grad);

// naive implementations: parallel across rays
torch::Tensor transmittance_from_sigma_forward_naive(
    torch::Tensor packed_info,
    torch::Tensor starts,
    torch::Tensor ends,
    torch::Tensor sigmas);
torch::Tensor transmittance_from_sigma_backward_naive(
    torch::Tensor packed_info,
    torch::Tensor starts,
    torch::Tensor ends,
    torch::Tensor transmittance,
    torch::Tensor transmittance_grad);
torch::Tensor transmittance_from_alpha_forward_naive(
    torch::Tensor packed_info, 
    torch::Tensor alphas);
torch::Tensor transmittance_from_alpha_backward_naive(
    torch::Tensor packed_info,
    torch::Tensor alphas,
    torch::Tensor transmittance,
    torch::Tensor transmittance_grad);

torch::Tensor weight_from_sigma_forward_naive(
    torch::Tensor packed_info,
    torch::Tensor starts,
    torch::Tensor ends,
    torch::Tensor sigmas);
torch::Tensor weight_from_sigma_backward_naive(
    torch::Tensor weights,
    torch::Tensor grad_weights,
    torch::Tensor packed_info,
    torch::Tensor starts,
    torch::Tensor ends,
    torch::Tensor sigmas);
torch::Tensor weight_from_alpha_forward_naive(
    torch::Tensor packed_info, 
    torch::Tensor alphas);
torch::Tensor weight_from_alpha_backward_naive(
    torch::Tensor weights,
    torch::Tensor grad_weights,
    torch::Tensor packed_info,
    torch::Tensor alphas);

// pdf
torch::Tensor pdf_sampling(
    torch::Tensor ts,      // [n_rays, n_samples_in]
    torch::Tensor weights, // [n_rays, n_samples_in - 1]
    int64_t n_samples,     // n_samples_out
    float padding,
    bool stratified,
    bool single_jitter,
    c10::optional<torch::Tensor> masks_opt);  // [n_rays]

torch::Tensor pdf_readout(
    // keys
    torch::Tensor ts,          // [n_rays, n_samples_in]
    torch::Tensor weights,     // [n_rays, n_bins_in]
    c10::optional<torch::Tensor> masks_opt, // [n_rays]
    // query
    torch::Tensor ts_out,
    c10::optional<torch::Tensor> masks_out_opt);      // [n_rays, n_samples_out]

PYBIND11_MODULE(TORCH_EXTENSION_NAME, m)
{
    // contraction
    py::enum_<ContractionType>(m, "ContractionType")
        .value("AABB", ContractionType::AABB)
        .value("UN_BOUNDED_TANH", ContractionType::UN_BOUNDED_TANH)
        .value("UN_BOUNDED_SPHERE", ContractionType::UN_BOUNDED_SPHERE);
    m.def("contract", &contract);
    m.def("contract_inv", &contract_inv);

    // grid
    m.def("grid_query", &grid_query);

    // marching
    m.def("ray_aabb_intersect", &ray_aabb_intersect);
    m.def("ray_marching", &ray_marching);

    // rendering
    m.def("is_cub_available", is_cub_available);
    m.def("transmittance_from_sigma_forward_cub", transmittance_from_sigma_forward_cub);
    m.def("transmittance_from_sigma_backward_cub", transmittance_from_sigma_backward_cub);
    m.def("transmittance_from_alpha_forward_cub", transmittance_from_alpha_forward_cub);
    m.def("transmittance_from_alpha_backward_cub", transmittance_from_alpha_backward_cub);
    
    m.def("transmittance_from_sigma_forward_naive", transmittance_from_sigma_forward_naive);
    m.def("transmittance_from_sigma_backward_naive", transmittance_from_sigma_backward_naive);
    m.def("transmittance_from_alpha_forward_naive", transmittance_from_alpha_forward_naive);
    m.def("transmittance_from_alpha_backward_naive", transmittance_from_alpha_backward_naive);

    m.def("weight_from_sigma_forward_naive", weight_from_sigma_forward_naive);
    m.def("weight_from_sigma_backward_naive", weight_from_sigma_backward_naive);
    m.def("weight_from_alpha_forward_naive", weight_from_alpha_forward_naive);
    m.def("weight_from_alpha_backward_naive", weight_from_alpha_backward_naive);

    // pack & unpack
    m.def("unpack_data", &unpack_data);
    m.def("unpack_info", &unpack_info);
    m.def("unpack_info_to_mask", &unpack_info_to_mask);

    // pdf
    m.def("pdf_sampling", &pdf_sampling);
    m.def("pdf_readout", &pdf_readout);
}