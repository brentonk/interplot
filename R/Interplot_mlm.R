#' Plot Conditional Coefficients in Mixed-Effects Models with Interaction Terms 
#' 
#' \code{interplot.mlm} is a method to calculate conditional coefficient estimates from the results of multilevel (mixed-effects) regression models with interaction terms. 
#' 
#' @param m A model object including an interaction term, or, alternately, a data frame recording conditional coefficients.
#' @param var1 The name (as a string) of the variable of interest in the interaction term; its conditional coefficient estimates will be plotted.
#' @param var2 The name (as a string) of the other variable in the interaction term.
#' @param plot A logical value indicating whether the output is a plot or a dataframe including the conditional coefficient estimates of var1, their upper and lower bounds, and the corresponding values of var2.
#' @param point A logical value determining the format of plot. By default, the function produces a line plot when var2 takes on ten or more distinct values and a point (dot-and-whisker) plot otherwise; option TRUE forces a point plot.
#' @param sims Number of independent simulation draws used to calculate upper and lower bounds of coefficient estimates: lower values run faster; higher values produce smoother curves.
#' @param xmin A numerical value indicating the minimum value shown of x shown in the graph. Rarely used.
#' @param xmax A numerical value indicating the maximum value shown of x shown in the graph. Rarely used.
#' 
#' @details \code{interplot.mlm} is a S3 method from the \code{interplot}. It works on mixed-effects objects with class \code{lmerMod} and \code{glmerMod}.
#' 
#' Because the output function is based on \code{\link[ggplot2]{ggplot}}, any additional arguments and layers supported by \code{ggplot2} can be added with the \code{+}. 
#' 
#' @return The function returns a \code{ggplot} object.
#' 
#' @importFrom  arm sim
#' @importFrom stats quantile
#' @import  ggplot2
#' 
#' 
#' 
#' @export

# Coding function for non-mi mlm objects
interplot.lmerMod <- function(m, var1, var2, plot = TRUE, point = FALSE, sims = 5000, 
    xmin = NA, xmax = NA) {
    set.seed(324)
    
    m.class <- class(m)
    m.sims <- arm::sim(m, sims)
    
    ### For factor base terms###
    factor_v1 <- factor_v2 <- FALSE
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1)))) & is.factor(eval(parse(text = paste0("m@frame$", 
        var2))))) 
        stop("The function does not support interactions between two factors.")
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1))))) {
        var1_bk <- var1
        var1 <- paste0(var1, levels(eval(parse(text = paste0("m@frame$", var1)))))
        factor_v1 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", var1, "and", 
                  var2, "."))
        }
    } else if (is.factor(eval(parse(text = paste0("m@frame$", var2))))) {
        var2_bk <- var2
        var2 <- paste0(var2, levels(eval(parse(text = paste0("m@frame$", var2)))))
        factor_v2 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", var1, "and", 
                  var2, "."))
        }
    } else {
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1))
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", var1, "and", 
                  var2, "."))
        }
    }
    
    ################### 
    
    if (factor_v2) {
        xmin <- 0
        xmax <- 1
        steps <- 2
    } else {
        if (is.na(xmin)) 
            xmin <- min(m@frame[var2], na.rm = T)
        if (is.na(xmax)) 
            xmax <- max(m@frame[var2], na.rm = T)
        
        steps <- eval(parse(text = paste0("length(unique(na.omit(m@frame$", var2, 
            ")))")))
        if (steps > 100) 
            steps <- 100  # avoid redundant calculation
    }
    
    coef <- data.frame(fake = seq(xmin, xmax, length.out = steps), coef1 = NA, 
        ub = NA, lb = NA)
    coef_df <- data.frame(fake = numeric(0), coef1 = numeric(0), ub = numeric(0), 
        lb = numeric(0), model = character(0))
    
    if (factor_v1) {
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", var1_bk))))) - 
            1)) {
            # only n - 1 interactions; one category is avoided against multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1[j + 1], unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1[j + 1], unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.975)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1[j + 1], unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.025)
            }
            
            if (plot == TRUE) {
                coef$value <- var1[j + 1]
                coef_df <- rbind(coef_df, coef)
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, point = point) + facet_grid(. ~ value)
        
    } else if (factor_v2) {
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", var2_bk))))) - 
            1)) {
            # only n - 1 interactions; one category is avoided against multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.975)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.025)
            }
            
            if (plot == TRUE) {
                coef$value <- var2[j + 1]
                coef_df <- rbind(coef_df, coef)
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, point = point) + facet_grid(. ~ value)
        
        
    } else {
        for (i in 1:steps) {
            coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                coef$fake[i] * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))])
            coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                coef$fake[i] * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))], 
                0.975)
            coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                coef$fake[i] * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))], 
                0.025)
        }
        
        if (plot == TRUE) {
            interplot.plot(m = coef, point = point)
        } else {
            names(coef) <- c(var2, "coef", "ub", "lb")
            return(coef)
        }
        
    }
}

#' @export
interplot.glmerMod <- function(m, var1, var2, plot = TRUE, point = FALSE, sims = 5000, 
    xmin = NA, xmax = NA) {
    set.seed(324)
    
    m.class <- class(m)
    m.sims <- arm::sim(m, sims)
    
    ### For factor base terms###
    factor_v1 <- factor_v2 <- FALSE
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1)))) & is.factor(eval(parse(text = paste0("m@frame$", 
        var2))))) 
        stop("The function does not support interactions between two factors.")
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1))))) {
        var1_bk <- var1
        var1 <- paste0(var1, levels(eval(parse(text = paste0("m@frame$", var1)))))
        factor_v1 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", var1, "and", 
                  var2, "."))
        }
    } else if (is.factor(eval(parse(text = paste0("m@frame$", var2))))) {
        var2_bk <- var2
        var2 <- paste0(var2, levels(eval(parse(text = paste0("m@frame$", var2)))))
        factor_v2 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", var1, "and", 
                  var2, "."))
        }
    } else {
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1))
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", var1, "and", 
                  var2, "."))
        }
    }
    
    ################### 
    
    if (factor_v2) {
        xmin <- 0
        xmax <- 1
        steps <- 2
    } else {
        if (is.na(xmin)) 
            xmin <- min(m@frame[var2], na.rm = T)
        if (is.na(xmax)) 
            xmax <- max(m@frame[var2], na.rm = T)
        
        steps <- eval(parse(text = paste0("length(unique(na.omit(m@frame$", var2, 
            ")))")))
        if (steps > 100) 
            steps <- 100  # avoid redundant calculation
    }
    
    coef <- data.frame(fake = seq(xmin, xmax, length.out = steps), coef1 = NA, 
        ub = NA, lb = NA)
    coef_df <- data.frame(fake = numeric(0), coef1 = numeric(0), ub = numeric(0), 
        lb = numeric(0), model = character(0))
    
    if (factor_v1) {
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", var1_bk))))) - 
            1)) {
            # only n - 1 interactions; one category is avoided against multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1[j + 1], unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1[j + 1], unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.975)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1[j + 1], unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.025)
            }
            
            if (plot == TRUE) {
                coef$value <- var1[j + 1]
                coef_df <- rbind(coef_df, coef)
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, point = point) + facet_grid(. ~ value)
        
    } else if (factor_v2) {
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", var2_bk))))) - 
            1)) {
            # only n - 1 interactions; one category is avoided against multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.975)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  0.025)
            }
            
            if (plot == TRUE) {
                coef$value <- var2[j + 1]
                coef_df <- rbind(coef_df, coef)
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, point = point) + facet_grid(. ~ value)
        
        
    } else {
        for (i in 1:steps) {
            coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                coef$fake[i] * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))])
            coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                coef$fake[i] * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))], 
                0.975)
            coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                coef$fake[i] * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))], 
                0.025)
        }
        
        if (plot == TRUE) {
            interplot.plot(m = coef, point = point)
        } else {
            names(coef) <- c(var2, "coef", "ub", "lb")
            return(coef)
        }
        
    }
} 
