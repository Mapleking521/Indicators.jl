# TODO: add abilities to use different MA types for trima, macd, bbands, etc

@doc doc"""
sma{Float64}(x::Vector{Float64}, n::Int64=10)

Simple moving average
""" ->
function sma{Float64}(x::Vector{Float64}, n::Int64=10)
	return runmean(x, n, false)
end

@doc doc"""
trima{Float64}(x::Vector{Float64}, n::Int64=10)

Triangular moving average
""" ->
function trima{Float64}(x::Vector{Float64}, n::Int64=10; ma::Function=sma)
    return ma(ma(x, n), n)
end

@doc doc"""
wma{Float64}(x::Vector{Float64}, n::Int64=10; wts::Vector{Float64}=collect(1:n)/sum(1:n))

Weighted moving average
""" ->
function wma{Float64}(x::Vector{Float64}, n::Int64=10; wts::Vector{Float64}=collect(1:n)/sum(1:n))
    @assert n<size(x,1) && n>0 "Argument n out of bounds"
	out = fill(NaN, size(x,1))
    @inbounds for i = n:size(x,1)
        out[i] = (wts' * x[i-n+1:i])[1]
    end
    return out
end

@doc doc"""
ema{Float64}(x::Vector{Float64}, n::Int64=10; alpha=2.0/(n+1), wilder::Bool=false)

Exponential moving average
""" ->
function ema{Float64}(x::Vector{Float64}, n::Int64=10; alpha=2.0/(n+1), wilder::Bool=false)
    @assert n<size(x,1) && n>0 "Argument n out of bounds."
    if wilder
        alpha = 1.0/n
    end
	out = fill(NaN, size(x,1))
    i = first(find(!isnan(x)))
    out[n+i-1] = mean(x[i:n+i-1])
    @inbounds for i = n+i:size(x,1)
        out[i] = alpha * (x[i] - out[i-1]) + out[i-1]
    end
    return out
end

@doc doc"""
dema{Float64}(x::Vector{Float64}, n::Int64=10; alpha=2.0/(n+1), wilder::Bool=false)

Double exponential moving average
""" ->
function dema{Float64}(x::Vector{Float64}, n::Int64=10; alpha=2.0/(n+1), wilder::Bool=false)
    return 2.0 * ema(x, n, alpha=alpha, wilder=wilder) - 
        ema(ema(x, n, alpha=alpha, wilder=wilder),
            n, alpha=alpha, wilder=wilder)
end

@doc doc"""
tema{Float64}(x::Vector{Float64}, n::Int64=10; alpha=2.0/(n+1), wilder::Bool=false)

Triple exponential moving average
""" ->
function tema{Float64}(x::Vector{Float64}, n::Int64=10; alpha=2.0/(n+1), wilder::Bool=false)
    return 3.0 * ema(x, n, alpha=alpha, wilder=wilder) - 
        3.0 * ema(ema(x, n, alpha=alpha, wilder=wilder),
                  n, alpha=alpha, wilder=wilder) +
        ema(ema(ema(x, n, alpha=alpha, wilder=wilder),
                n, alpha=alpha, wilder=wilder),
            n, alpha=alpha, wilder=wilder)
end

@doc doc"""
mama{Float64}(x::Vector{Float64}, fastlimit::Float64=0.5, slowlimit::Float64=0.05)

MESA adaptive moving average (developed by John Ehlers)
""" ->
function mama{Float64}(x::Vector{Float64}, fastlimit::Float64=0.5, slowlimit::Float64=0.05)
    n = size(x,1)
    out = zeros(n,2)
    smooth = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    detrend = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    Q1 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    I1 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    I2 = [0.0, 0.0]
    Q2 = [0.0, 0.0]
    Re = [0.0, 0.0]
    Im = [0.0, 0.0]
    per = [0.0, 0.0]
    sper = [0.0, 0.0]
    phase = [0.0, 0.0]
    jI = 0.0
    jQ = 0.0
    dphase = 0.0
    alpha = 0.0
    a = 0.0962
    b = 0.5769
    @inbounds for i = 13:n
        # Smooth and detrend price movement ====================================
        smooth[7] = (4*x[i] + 3*x[i-1] + 2*x[i-2] + x[i-3]) * 0.1
        detrend[7] = (0.0962*smooth[7]+0.5769*smooth[5]-0.5769*smooth[3]-0.0962*smooth[1]) * (0.075*per[1]+0.54)
        # Compute InPhase and Quandrature components ===========================
        Q1[7] = (0.0962*detrend[7]+0.5769*detrend[5]-0.5769*detrend[3]-0.0962*detrend[1]) * (0.075*per[1]+0.54)
        I1[7] = detrend[4]
        # Advance phase of I1 and Q1 by 90 degrees =============================
        jQ = (0.0962*Q1[7]+0.5769*Q1[5]-0.5769*Q1[3]-0.0962*Q1[1]) * (0.075*per[1]+0.54)
        jI = (0.0962*I1[7]+0.5769*I1[5]-0.5769*I1[3]-0.0962*I1[1]) * (0.075*per[1]+0.54)
        # Phasor addition for 3 bar averaging ==================================
        Q2[2] = Q1[7] + jI
        I2[2] = I1[7] - jQ
        # Smooth I & Q components before applying the discriminator ============
        Q2[2] = 0.2 * Q2[2] + 0.8 * Q2[1]
        I2[2] = 0.2 * I2[2] + 0.8 * I2[1]
        # Homodyne discriminator ===============================================
        Re[2] = I2[2] * I2[1] + Q2[2]*Q2[1]
        Im[2] = I2[2] * Q2[1] - Q2[2]*I2[1]
        Re[2] = 0.2 * Re[2] + 0.8*Re[1]
        Im[2] = 0.2 * Im[2] + 0.8*Im[1]
        if (Im[2] != 0.0) & (Re[2] != 0.0)
            per[2] = 360.0/atan(Im[2]/Re[2])
        end
        if per[2] > 1.5 * per[1]
            per[2] = 1.5*per[1]
        elseif per[2] < 0.67 * per[1]
            per[2] = 0.67 * per[1]
        end
        if per[2] < 6.0
            per[2] = 6.0
        elseif per[2] > 50.0
            per[2] = 50.0
        end
        per[2] = 0.2*per[2] + 0.8*per[1]
        sper[2] = 0.33*per[2] + 0.67*sper[1]
        if I1[7] != 0.0
            phase[2] = atan(Q1[7]/I1[7])
        end
        dphase = phase[1] - phase[2]
        if dphase < 1.0
            dphase = 1.0
        end
        alpha = fastlimit / dphase
        if alpha < slowlimit
            alpha = slowlimit
        end
        out[i,1] = alpha*x[i] + (1.0-alpha)*out[i-1,1]
        out[i,2] = 0.5*alpha*out[i,1] + (1.0-0.5*alpha)*out[i-1,2]
        # Reset/increment array variables
        smooth = [smooth[2:7]; smooth[7]]
        detrend = [detrend[2:7]; detrend[7]]
        Q1 = [Q1[2:7]; Q1[7]]
        I1 = [I1[2:7]; I1[7]]
        I2[1] = I2[2]
        Q2[1] = Q2[2]
        Re[1] = Re[2]
        Im[1] = Im[2]
        per[1] = per[2]
        sper[1] = sper[2]
        phase[1] = phase[2]
    end
    out[1:32,:] = NaN
    return out
end


@doc doc"""
hma{Float64}(x::Vector{Float64}, n::Int64=1)

Hull moving average
""" ->
function hma{Float64}(x::Vector{Float64}, n::Int64=20)
    return wma(2 * wma(x, Int64(round(n/2.0))) - wma(x, n), Int64(trunc(sqrt(n))))
end

@doc doc"""
swma{Float64}(x::Vector{Float64}, n::Int64)

Sine-weighted moving average
""" ->
function swma{Float64}(x::Vector{Float64}, n::Int64=10)
    @assert n<size(x,1) && n>0 "Argument n out of bounds."
    w = sin(collect(1:n) * 180.0/6.0)  # numerator weights
    d = sum(w)  # denominator = sum(numerator weights)
    @inbounds for i = n:size(x,1)
        out[i] = sum(w .* x[i-n+1:i]) / d
    end
    return out
end

