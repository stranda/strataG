#' @title Read fastsimcoal output
#' @description Read arlequin formatted output or parameter estimation files 
#'   generated by fastsimcoal
#'   
#' @param p list of fastsimcoal parameters output from \code{\link{fscRun}}.
#' @param sim one or two-element numberic vector giving the number of the
#'   simulation replicate (and sub-replicate) to read. For example, \code{sim =
#'   c(3, 5)} will attempt to read "<label>_3_5.arp".
#' @param marker type of marker to return.
#' @param chrom numerical vector giving chromosomes to return. If \code{NULL}
#'   all chromosomes are returned.
#' @param sep.chrom return a list of separate chromosomes?
#' @param drop.mono return only polymorphic loci?
#' @param as.genotypes return data as genotypes? If \code{FALSE}, original
#'   haploid data is returned. If \code{TRUE}, individuals are created by
#'   combining sequential haplotypes based on the ploidy used to run the
#'   simulation.
#' @param one.col return genotypes with one column per locus? If \code{FALSE},
#'   alleles are split into separate columns and designated as ".1", ".2", etc.
#'   for each locus.
#' @param sep character to use to separate alleles if \code{one.col = TRUE}.
#' @param coded.snps return diploid SNPs coded as 0 (major allele homozygote), 1
#'   (heterozygote), or 2 (minor allele homozygote). If this is \code{TRUE} and
#'   \code{marker = "snp"} (or only SNPs are present) and the data is diploid,
#'   genotypes will be returned with one column per locus.
#' @param concat.dna logical. concatenate multiple DNA blocks into single 
#'   locus?
#' @param ... arguments to be passed to \code{fscReadArp}.
#'   
#' @return 
#' \describe{
#'  \item{fscReadArp}{Reads and parses Arlequin-formatted .arp output files 
#'    created by \code{fastsimcoal2}. Returns a data frame of genotypes, with 
#'    individuals created by combining haplotypes based on the stored value of
#'    ploidy specified when the simulation was run.}
#'  \item{fscReadParamEst}{Reads and parses files output from a 
#'    \code{fastsimcoal2} run conducted for parameter estimation. Returns a list 
#'    of data frames and vectors containing the data from each file.}
#'  \item{fscReadSFS}{Reads site frequency spectra generated from 
#'    \code{fastsimcoal2}. Returns a list of the marginal and joint SFS, the 
#'    polymorphic sites, and the estimated maximum likelihood of the SFS."}
#'  \item{fsc2gtypes}{Creates a \linkS4class{gtypes} object from fastsimcoal2
#'    output.}
#'  }
#'  
#' @note \code{fastsimcoal2} is not included with `strataG` and must be
#'   downloaded separately. Additionally, it must be installed such that it can
#'   be run from the command line in the current working directory. 
#'   The function \code{fscTutorial()} will open a detailed tutorial on the 
#'   interface in your web browser.
#' 
#' @references Excoffier, L. and Foll, M (2011) fastsimcoal: a continuous-time 
#'   coalescent simulator of genomic diversity under arbitrarily complex 
#'   evolutionary scenarios Bioinformatics 27: 1332-1334.\cr
#'   Excoffier, L., Dupanloup, I., Huerta-Sánchez, E., Sousa, V.C., 
#'   and M. Foll (2013) Robust demographic inference from genomic and SNP data. 
#'   PLOS Genetics, 9(10):e1003905. \cr
#'   \url{http://cmpg.unibe.ch/software/fastsimcoal2/}
#' 
#' @author Eric Archer \email{eric.archer@@noaa.gov}
#' 
#' @seealso \code{\link{fsc.input}}, \code{\link{fscWrite}}, 
#'  \code{\link{fscRun}}
#'  
#' @examples \dontrun{
#' #' # three demes with optional names
#' demes <- fscSettingsDemes(
#'   Large = fscDeme(10000, 10), 
#'   Small = fscDeme(2500, 10),
#'   Medium = fscDeme(5000, 3, 1500)
#' )
#' 
#' # four historic events
#' events <- fscSettingsEvents(
#'   fscEvent(event.time = 2000, source = 1, sink = 2, prop.migrants = 0.05),
#'   fscEvent(2980, 1, 1, 0, 0.04),
#'   fscEvent(3000, 1, 0),
#'   fscEvent(15000, 0, 2, new.size = 3)
#'  )
#'  
#' # four genetic blocks of different types on three chromosomes.  
#' genetics <- fscSettingsGenetics(
#'   fscBlock_snp(10, 1e-6, chromosome = 1),
#'   fscBlock_dna(10, 1e-5, chromosome = 1),
#'   fscBlock_microsat(3, 1e-4, chromosome = 2),
#'   fscBlock_standard(5, 1e-3, chromosome = 3)
#' )
#' 
#' params <- fscWrite(demes = demes, events = events, genetics = genetics)
#' 
#' # runs 100 replicates, converting all DNA sequences to 0/1 SNPs
#' # will also output the MAF site frequency spectra (SFS) for all SNP loci.
#' params <- fscRun(params, num.sim = 100, dna.to.snp = TRUE, num.cores = 3)
#' 
#' # extracting only microsattelite loci from simulation replicate 1
#' msats <- fscReadArp(params, marker = "microsat")
#' 
#' # read SNPs from simulation replicate 5 with genotypes coded as 0/1
#' snp.5 <- fscReadArp(params, sim = 1, marker = "snp", coded.snps = TRUE
#' 
#' # read SFS for simulation 20
#' sfs.20 <- fscReadSFS(params, sim = 20)
#' }
#' 
#' @name fscRead
#' @export
#' 
fscReadArp <- function(p, sim = c(1, 1),
                       marker = c("all", "snp", "microsat", "dna", "standard"),
                       chrom = NULL, sep.chrom = FALSE, drop.mono = FALSE, 
                       as.genotypes = TRUE, one.col = FALSE, sep = "/", 
                       coded.snps = FALSE) {
  if(length(sim) == 1) sim <- c(1, sim)
  if(length(sim) != 2) stop("'sim' must be a two-element numeric vector.")
  arp <- file.path(p$folder, p$label, paste0(p$label, "_", sim[1], "_", sim[2], ".arp"))
  if(!file.exists(arp)) stop("Can't find .arp file, '", arp, "'.")
  if(is.null(p$locus.info)) {
    stop("'p' must be a list returned by 'fscRun()' and contain a $locus.info element")
  }
  hap.data <- .fscParseGeneticData(p, arp)
  if(is.null(hap.data)) return(NULL)
  file <- attr(hap.data, "file")
  hap.data <- .fscSelectLoci(hap.data, p$locus.info, marker, chrom)
  # drop monomorphic sites if requested
  if(drop.mono & is.null(attr(hap.data, "poly.pos"))) {
    is.poly <- apply(hap.data[, -(1:2)], 2, function(x) {
      dplyr::n_distinct(x) > 1
    })
    hap.data <- hap.data[, c(1:2, which(is.poly) + 2)]
  }
  ploidy <- attr(p$settings$demes, "ploidy")
  data.mat <- if(as.genotypes & ploidy > 1) {
    .fscFormatGenotypes(hap.data, sep.chrom, ploidy, one.col, sep, coded.snps)
  } else as.data.frame(hap.data, stringsAsFactors = FALSE)
  data.mat$deme <- p$settings$demes$deme.name[as.numeric(data.mat$deme)]
  attr(data.mat, "poly.pos") <- attr(hap.data, "poly.pos")
  attr(data.mat, "file") <- file
  data.mat
}


#' @noRd
#' 
.fscParseGeneticData <- function(p, file) {
  data.mat <- .fscParseArpFile(file)
  if(is.null(data.mat)) return(NULL)
  
  # parse data matrix with locus.info mapping
  cat(format(Sys.time()), "parsing genetic data...\n")
  gen.data <- if(is.null(attr(data.mat, "poly.pos"))) {
    .fscParseAllSites(p$locus.info, data.mat)
  } else {
    .fscParsePolySites(p$locus.info, data.mat)
  }
  attr(gen.data, "file") <- file
  
  invisible(gen.data)
}


#' @noRd
#' 
.fscParseArpFile <- function(fname) {
  # read .arp file
  cat(format(Sys.time()), "reading", fname, "\n")
  f <- scan(
    fname, 
    what = "character", 
    sep = "\n", 
    quiet = TRUE
  )
  f <- stringi::stri_trim_both(f)
  f <- f[f != ""]
  
  # get information on polymorphic sites
  chrom.lines <- grep("polymorphic positions on", f)
  poly.pos <- if(length(chrom.lines) != 0) {
    num.poly <- f[chrom.lines]
    num.poly <- regmatches(num.poly, regexpr("[[:digit:]]+", num.poly))
    chrom.poly <- which(as.numeric(num.poly) > 0)
    if(length(chrom.poly) > 0) {
      poly.pos <- f[chrom.lines[chrom.poly] + 1]
      poly.pos <- regmatches(poly.pos, gregexpr("[[:digit:]]+", poly.pos))
      do.call(rbind, lapply(1:length(poly.pos), function(i) {
        cbind(chromosome = chrom.poly[i], position = as.numeric(poly.pos[[i]]))
      }))
    } else {
      warning("No polymorphic sites found. NULL returned.", call. = FALSE)
      return(NULL)
    }
  } else NULL
  
  # get start and end points of data blocks
  start <- grep("SampleData=", f)
  end <- which(f == "}")
  end <- sapply(start, function(x) end[which.max(end > x)])
  pos <- cbind(start = start + 1, end = end - 1)
  
  data.mat <- if(any((pos[, "end"] - pos[, "start"]) > 0)) {
    # extract matrix for each data block
    data.mat <- do.call(rbind, lapply(1:nrow(pos), function(i) {
      f.line <- f[pos[i, "start"]:pos[i, "end"]]
      # make matrix and remove remove frequency column
      result <- do.call(rbind, strsplit(f.line, "[[:space:]]+"))[, -2]
      ## return id, deme number (i), and data columns
      if (is.null(dim(result))) #deal with occasional change from mat to vector
      {
          cbind(result[1],i,result[2])
          
      } else {
          cbind(result[, 1], rep(i, nrow(result)), result[, -1])
      }
    }))
    colnames(data.mat) <- c("id", "deme", paste0("col", 3:ncol(data.mat)))
    data.mat
  } else NULL
  
  if(!is.null(data.mat)) attr(data.mat, "poly.pos") <- poly.pos
  data.mat
}


#' @noRd
#' 
.fscParseAllSites <- compiler::cmpfun(function(locus.info, data.mat) {
  # for each row in locus.info, create matrix of loci in that block
  # return list of block matrices
  gen.data <- vector("list", nrow(locus.info))
  for(i in 1:nrow(locus.info)) {
    cols <- data.mat[, locus.info$mat.col.start[i]:locus.info$mat.col.end[i]]
    # extract DNA sequence from string in column
    if(locus.info$fsc.type[i] == "DNA") {
      start <- locus.info$dna.start[i]
      end <- locus.info$dna.end[i]
      if(any(is.na(c(start, end)))) {
        start <- 1
        end <- nchar(cols[1])
      }
      cols <- stringi::stri_sub(cols, start, end)
      if(locus.info$actual.type[i] == "SNP") {
        cols <- do.call(rbind, strsplit(cols, ""))
      }
    }
    cols <- cbind(cols)
    # give suffixes to block names with more than one locus
    colnames(cols) <- if(ncol(cols) == 1) {
      locus.info$name[i] 
    } else {
      paste0(locus.info$name[i], "_L", .zeroPad(1:ncol(cols)))
    }
    gen.data[[i]] <- cols
  }
  
  # create map of column numbers in gen.data for each row of locus.info
  last.col <- 2
  locus.cols <- vector("list", nrow(locus.info))
  names(locus.cols) <- locus.info$name
  for(i in 1:length(gen.data)) {
    locus.cols[[i]] <- (last.col + 1):(last.col + ncol(gen.data[[i]]))
    last.col <- max(locus.cols[[i]])
  }
  
  gen.data <- do.call(cbind, gen.data)
  gen.data <- cbind(data.mat[, 1:2], gen.data)  
  attr(gen.data, "locus.cols") <- locus.cols
  gen.data
})


#' @noRd
#' 
.fscParsePolySites <- function(locus.info, data.mat) {
  poly.pos <- attr(data.mat, "poly.pos")
  
  loc.info.row <- apply(poly.pos, 1, function(x) {
    chr.rows <- which(locus.info$chromosome == x["chromosome"])
    i <- findInterval(
      x["position"], 
      locus.info[chr.rows, "chrom.pos.start"]
    )
    chr.rows[i]
  })
  
  poly.pos <- cbind(poly.pos, loc.info.row = loc.info.row) %>% 
    as.data.frame() %>% 
    dplyr::mutate(
      name = locus.info[.data$loc.info.row, "name"],
      actual.type = locus.info[.data$loc.info.row, "actual.type"],
      fsc.type = locus.info[.data$loc.info.row, "fsc.type"]
    ) 
  
  prev.type <- dplyr::lag(poly.pos$fsc.type)
  same.col <- as.numeric(!(poly.pos$fsc.type == "DNA" & prev.type == "DNA"))
  same.col[1] <- 1
  poly.pos$mat.col <- cumsum(same.col) + 2
  
  poly.pos <- poly.pos %>% 
    dplyr::group_by(.data$mat.col) %>% 
    dplyr::mutate(dna.pos = ifelse(.data$fsc.type == "DNA", 1:dplyr::n(), NA)) %>% 
    dplyr::ungroup() %>% 
    as.data.frame()
  
  poly.pos <- split(poly.pos, poly.pos$name)
  gen.data <- vector("list", length(poly.pos))
  for(i in 1:length(poly.pos)) {
    name.df <- poly.pos[[i]]
    cols <- data.mat[, sort(unique(name.df$mat.col))]
    marker.type <- unique(name.df$actual.type)
    if(marker.type %in% c("DNA", "SNP")) {
      n <- nrow(name.df)
      cols <- stringi::stri_sub(cols, name.df$dna.pos[1], name.df$dna.pos[n])
      if(marker.type == "SNP") cols <- do.call(rbind, strsplit(cols, ""))
    }
    cols <- cbind(cols)
    # give suffixes to block names with more than one locus
    colnames(cols) <- if(ncol(cols) == 1) {
      name.df$name[1]
    } else {
      paste0(name.df$name[1], "_L", .zeroPad(1:ncol(cols)))
    }
    gen.data[[i]] <- cols
  }
  
  # create map of column numbers in gen.data for each row of locus.info
  last.col <- 2
  locus.cols <- vector("list", length(poly.pos))
  names(locus.cols) <- names(poly.pos)
  for(i in 1:length(gen.data)) {
    locus.cols[[i]] <- (last.col + 1):(last.col + ncol(gen.data[[i]]))
    last.col <- max(locus.cols[[i]])
  }
  
  gen.data <- do.call(cbind, gen.data)
  gen.data <- cbind(data.mat[, 1:2], gen.data)  
  attr(gen.data, "locus.cols") <- locus.cols
  attr(gen.data, "poly.pos") <- do.call(rbind, poly.pos)
  rownames(attr(gen.data, "poly.pos")) <- NULL
  gen.data
}


#' @noRd
#' 
.fscSelectLoci <- function(hap.data, locus.info, marker, chrom) {
  poly.pos <- attr(hap.data, "poly.pos")
  
  # filter locus info for specified chromosomes
  if(!is.null(chrom)) {
    if(!is.numeric(chrom)) stop("'chrom' must be a numeric vector")
    if(max(chrom) > max(locus.info$chromosome)) {
      stop("there are not", max(chrom), "chromosomes available") 
    }
    locus.info <- locus.info[locus.info$chromosome %in% chrom, ]
  }
  
  # check that requested marker type is available
  marker <- toupper(marker)
  if(!all(marker %in% c("DNA", "SNP", "MICROSAT", "STANDARD", "ALL"))) {
    stop("`marker` can only contain 'dna', 'snp', 'microsat', 'standard', 'all'.")
  }
  if("ALL" %in% marker) marker <- unique(locus.info$actual.type)
  
  # filter locus info for requested marker types
  i <- grep(paste(marker, collapse = "|"), locus.info$name)
  if(length(i) == 0) {
    stop("No loci available for selected marker types on selected chromosomes.")
  }
  locus.info <- locus.info[i, , drop = FALSE]
  
  # extract columns for selected chromosomes and marker types
  loc.cols <- unlist(attr(hap.data, "locus.cols")[locus.info$name]) 
  hap.data <- hap.data[, c(1:2, loc.cols), drop = FALSE]
  
  if(!is.null(poly.pos)) {
    poly.pos <- poly.pos[poly.pos$name %in% colnames(hap.data), , drop = FALSE]
    attr(hap.data, "poly.pos") <- poly.pos
  }
  hap.data
}


#' @noRd
#' 
.fscFormatGenotypes <- function(hap.data, sep.chrom, ploidy, one.col, sep, 
                                coded.snps) {  
  if(coded.snps) { # check that coded SNPs can be returned
    num.snp.cols <- grepl("_SNP", colnames(hap.data)) # all loci must be SNPs
    if(!sum(num.snp.cols) == ncol(hap.data) - 2) {
      stop("Select `marker = \"snp\"` to return coded SNPs.")
    }
    if(ploidy != 2) stop("Can't code SNPs in non-diploid data.")
  }
  
  # vector of numeric ids to group alleles for individuals
  gen.id <- rep(1:(nrow(hap.data) / ploidy), each = ploidy)
  
  gen.df <- if(one.col | coded.snps) {
    # matrix of id and deme for each individual
    id.mat <- do.call(rbind, tapply(1:nrow(hap.data), gen.id, function(i) {
      c(
        id = paste(hap.data[i, "id"], collapse = sep), 
        deme = hap.data[i, "deme"][1]
      )
    })) %>% 
      as.data.frame(stringsAsFactors = FALSE)
    # matrix of genotypes with one column per locus
    gen.mat <- apply(hap.data[, -(1:2), drop = FALSE], 2, function(loc) {
      if(coded.snps) {
        major.allele <- names(which.max(table(loc)))
        tapply(loc, gen.id, function(x) sum(x != major.allele))
      } else {
        tapply(loc, gen.id, paste, collapse = sep)
      }
    })
    cbind(id.mat, gen.mat, stringsAsFactors = FALSE)
  } else {
    # matrix of ids, demes, and genotypes with ploidy columns per locus
    gen.mat <- do.call(rbind, tapply(1:nrow(hap.data), gen.id, function(i) {
      id <- paste(hap.data[i, "id"], collapse = sep)
      c(id = id, deme = hap.data[i, "deme"][1], as.vector(hap.data[i, -(1:2)]))
    }))
    colnames(gen.mat)[-(1:2)] <- paste(
      rep(colnames(hap.data)[-(1:2)], each = ploidy), 
      1:ploidy, 
      sep = "."
    )
    as.data.frame(gen.mat, stringsAsFactors = FALSE)
  }
  
  if(sep.chrom) {
    chroms <- unique(regmatches(
      colnames(gen.df),
      regexpr("^C[[:digit:]]+", colnames(gen.df))
    ))
    sapply(chroms, function(x) {
      chr <- grep(x, colnames(gen.df), value = T)
      gen.df[, c(1:2, which(colnames(gen.df) %in% chr))]
    }, simplify = FALSE)
  } else gen.df
}


# Estimated Parameters ---------------------------------------------------------

#' @rdname fscRead
#' @export
#' 
fscReadParamEst <- function(p) {
  out <- list(
    sfs = .fscReadEstSFS(p),
    max.lhoods = .fscReadMaxLhoods(p), 
    ecm.lhoods = .fscReadLhoods(p)
  )
  if(all(sapply(out, is.null))) stop("No parameter estimation files found.")
  out
}


#' @noRd
#' 
.fscReadEstSFS <- function(p) {
  marginal.pattern <- "_[MD]AFpop[[:digit:]]+.txt$" 
  folder <- file.path(p$folder, p$label)
  marginal.fnames <- dir(folder, pattern = marginal.pattern, full.names = T)
  marginal.sfs <- if(length(marginal.fnames) == 0) NULL else {
    sapply(marginal.fnames, function(fname) {
      mat <- utils::read.table(fname, header = TRUE, sep = "\t")
      mat <- as.matrix(mat)
      mat[1, -ncol(mat)]
    })
  }
  
  joint.pattern <- "_joint[MD]AFpop[[:digit:]]+_[[:digit:]]+.txt$"
  folder <- file.path(p$folder, p$label)
  joint.fnames <- dir(folder, pattern = joint.pattern, full.names = T)
  joint.sfs <- if(length(joint.fnames) == 0) NULL else {
    sapply(joint.fnames, function(fname) {
      mat <- utils::read.table(fname, header = TRUE, sep = "\t", row.names = 1)
      as.matrix(mat)
    })
  }

  list(marginal = marginal.sfs, joint = joint.sfs)
}


#' @noRd
#' 
.fscReadMaxLhoods <- function(p) {
  fname <- dir(p$label, pattern = ".bestlhoods$", full.names = T)
  if(length(fname) == 0) return(NULL)
  .fscReadVector(fname)
}


#' @noRd
#' 
.fscReadLhoods <- function(p) {
  folder <- file.path(p$folder, p$label)
  fname <- dir(folder, pattern = ".brent_lhoods$", full.names = T)
  if(length(fname) == 0) return(NULL)
  f <- scan(
    fname, 
    what = "character", 
    sep = "\n", 
    quiet = TRUE, 
    blank.lines.skip = FALSE
  )
  f <- f[grep("^Param|^[[:digit:]]", f)]
  f <- strsplit(f, "\t")
  x <- as.data.frame(do.call(rbind, lapply(f[-1], as.numeric)))
  colnames(x) <- f[[1]][1:ncol(x)]
  x
}


#' @noRd
#' 
.fscReadVector <- function(fname) {    
  f <- scan(
    fname, 
    what = "character", 
    sep = "\n", 
    quiet = TRUE, 
    blank.lines.skip = FALSE
  )
  stats::setNames(
    as.numeric(do.call(c, strsplit(f[2], "\t"))),
    do.call(c, strsplit(f[1], "\t"))
  )
}


# SFS --------------------------------------------------------------------------

#' @rdname fscRead
#' @export
#' 
fscReadSFS <- function(p, sim = 1) {
  dir.name <- paste0(p$label, "_", sim)
  folder <- file.path(p$folder, p$label)
  sfs.dir <- dir(folder, pattern = dir.name, full.names = TRUE)
  if(length(sfs.dir) == 0) {
    stop("Can't find '", dir.name, "' in '", p$label, "' .")
  }
  sfs.dir <- sfs.dir[1]
  cat(format(Sys.time()), "reading files in", sfs.dir, "\n")
  
  list(
    sfs = list(
      marginal = .fscReadObsSFS(sfs.dir, TRUE),
      joint = .fscReadObsSFS(sfs.dir, FALSE)
    ),
    polym.sites = .fscReadSFSPolymSites(sfs.dir),
    lhood = .fscReadSFSLhood(p$label, sim)
  )
}


#' @noRd
#' 
.fscReadObsSFS <- function(sfs.dir, marginal) {
  pattern <- if(marginal) {
    "_[MD]AFpop[[:digit:]]+.obs$"
  } else {
    "_joint[MD]AFpop[[:digit:]]+_[[:digit:]]+.obs$"
  }
  
  obs.files <- dir(sfs.dir, pattern = pattern, full.names = TRUE)
  if(length(obs.files) == 0) return(NULL)
  
  sapply(obs.files, function(fname) {
    mat <- utils::read.table(
      fname, header = TRUE, sep = "\t", row.names = if(marginal) NULL else 1,
      skip = 1
    )
    mat <- as.matrix(mat)
    if(marginal) mat[1, -ncol(mat)] else mat
  }, simplify = FALSE)
}


#' @noRd
#' 
.fscReadSFSPolymSites <- function(sfs.dir) {
  fname <- dir(sfs.dir, pattern = "_numPolymSites.obs$", full.names = TRUE)
  if(length(fname) == 0) return(NULL)
  f <- scan(
    fname, 
    what = "character", 
    sep = "\n", 
    skip = 1,
    quiet = TRUE, 
    blank.lines.skip = FALSE
  )
  stats::setNames(
    as.numeric(unlist(strsplit(f, "\t"))),
    c("num.sim", "num.polym", "num.gt2.alleles", "num.fix.anc", "num.no.anc")
  )
}


#' @noRd
#' 
.fscReadSFSLhood <- function(label, sim) {
  fname <- dir(label, pattern = ".lhoodObs$", full.names = TRUE)
  if(length(fname) == 0) return(NULL)
  f <- utils::read.table(fname, header = TRUE, sep = "\t")
  f[1, sim + 2]
}


# Convert to gtypes -------------------------------------------------------

#' @rdname fscRead
#' @export
#' 
fsc2gtypes <- function(
  p, marker = c("dna", "snp", "microsat"), concat.dna = TRUE, ...
) {
  marker <- match.arg(marker)
  if(!marker %in% c("dna", "snp", "microsat")) {
    stop("'marker' must be 'dna', 'snp', or 'microsat'")
  }
  ploidy <- attr(p$settings$demes, "ploidy")
  df <- fscReadArp(p, marker = marker, ...)
  if(ploidy == 1 & marker == "dna") {
    if(concat.dna | ncol(df) == 3) {
      seqs <- apply(df[, -(1:2)], 1, paste, collapse = "")
      seq.mat <- do.call(rbind, strsplit(df[, 3], ""))
      rownames(seq.mat) <- df[, 1]
      haps <- labelHaplotypes(ape::as.DNAbin(seq.mat))
      lbl <- if(ncol(df) > 3) {
        paste0(colnames(df)[3], ":", colnames(df)[ncol(df)])
      } else colnames(df)[3]
      df <- cbind(df[, 1:2], haps = unname(haps$haps))
      colnames(df)[3] <- lbl
      df2gtypes(
        df, ploidy = 1, sequences = haps$hap.seqs, description = p$label
      )
    } else {
      seqs <- sapply(colnames(df[, -(1:2)]), function(gene) {
        seq.mat <- do.call(rbind, strsplit(df[, gene], ""))
        rownames(seq.mat) <- df[, 1]
        ape::as.DNAbin(seq.mat)
      }, simplify = FALSE)
      
      df[, 3:ncol(df)] <- df[, 1]
      g <- df2gtypes(
        df,
        ploidy = 1,
        sequences = seqs,
        description = p$label
      )  
      
      labelHaplotypes(g)
    }
  } else {
    df2gtypes(df, ploidy = ploidy, description = p$label)
  }
}

