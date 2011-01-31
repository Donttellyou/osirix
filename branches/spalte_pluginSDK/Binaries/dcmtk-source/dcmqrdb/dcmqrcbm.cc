/*
 *
 *  Copyright (C) 1993-2005, OFFIS
 *
 *  This software and supporting documentation were developed by
 *
 *    Kuratorium OFFIS e.V.
 *    Healthcare Information and Communication Systems
 *    Escherweg 2
 *    D-26121 Oldenburg, Germany
 *
 *  THIS SOFTWARE IS MADE AVAILABLE,  AS IS,  AND OFFIS MAKES NO  WARRANTY
 *  REGARDING  THE  SOFTWARE,  ITS  PERFORMANCE,  ITS  MERCHANTABILITY  OR
 *  FITNESS FOR ANY PARTICULAR USE, FREEDOM FROM ANY COMPUTER DISEASES  OR
 *  ITS CONFORMITY TO ANY SPECIFICATION. THE ENTIRE RISK AS TO QUALITY AND
 *  PERFORMANCE OF THE SOFTWARE IS WITH THE USER.
 *
 *  Module:  dcmqrdb
 *
 *  Author:  Marco Eichelberg
 *
 *  Purpose: class DcmQueryRetrieveMoveContext
 *
 *  Last Update:      $Author: lpysher $
 *  Update Date:      $Date: 2006/03/01 20:16:07 $
 *  Source File:      $Source: /cvsroot/osirix/osirix/Binaries/dcmtk-source/dcmqrdb/dcmqrcbm.cc,v $
 *  CVS/RCS Revision: $Revision: 1.1 $
 *  Status:           $State: Exp $
 *
 *  CVS/RCS Log at end of file
 *
 */

#include "osconfig.h"    /* make sure OS specific configuration is included first */
#include "dcmqrcbm.h"

#include "dcmqrcnf.h"
#include "dcdeftag.h"
#include "dcmqropt.h"
#include "diutil.h"
#include "dcfilefo.h"
#include "dcmqrdbs.h"
#include "dcmqrdbi.h"

BEGIN_EXTERN_C
#ifdef HAVE_FCNTL_H
#include <fcntl.h>       /* needed on Solaris for O_RDONLY */
#endif
END_EXTERN_C


static void moveSubOpProgressCallback(void *callbackData, 
    T_DIMSE_StoreProgress *progress,
    T_DIMSE_C_StoreRQ * /*req*/)
{
  DcmQueryRetrieveMoveContext *context = OFstatic_cast(DcmQueryRetrieveMoveContext *, callbackData);
  if (context->isVerbose())
  {
    switch (progress->state)
    {
      case DIMSE_StoreBegin:
        printf("XMIT:");
        break;
      case DIMSE_StoreEnd:
        printf("\n");
        break;
      default:
        putchar('.');
        break;
    }
    fflush(stdout);
  }
}

OFBool DcmQueryRetrieveMoveContext::isVerbose() const 
{ 
  return options_.verbose_ ? OFTrue : OFFalse; 
}

void DcmQueryRetrieveMoveContext::callbackHandler(
	/* in */ 
	OFBool cancelled, T_DIMSE_C_MoveRQ *request, 
	DcmDataset *requestIdentifiers, int responseCount,
	/* out */
	T_DIMSE_C_MoveRSP *response, DcmDataset **stDetail,	
	DcmDataset **responseIdentifiers)
{
    OFCondition cond = EC_Normal;
    OFCondition dbcond = EC_Normal;
    DcmQueryRetrieveDatabaseStatus dbStatus(priorStatus);
    
    if (responseCount == 1) {
        /* start the database search */
	if (options_.verbose_) {
	    printf("Move SCP Request Identifiers:\n");
	    requestIdentifiers->print(COUT);
        }
        dbcond = dbHandle.startMoveRequest(
	    request->AffectedSOPClassUID, requestIdentifiers, &dbStatus);
        if (dbcond.bad()) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Database: startMoveRequest Failed (%s):",
		DU_cmoveStatusString(dbStatus.status()));
        }

        if (dbStatus.status() == STATUS_Pending) {
            /* If we are going to be performing sub-operations, build
             * a new association to the move destination.
             */
	    cond = buildSubAssociation(request);
	    if (cond == APP_INVALIDPEER) {
	        dbStatus.setStatus(STATUS_MOVE_Failed_MoveDestinationUnknown);
	    } else if (cond.bad()) {
	        /* failed to build association, must fail move */
		failAllSubOperations(&dbStatus);
	    }
        }
    }
    
    /* only cancel if we have pending status */
    if (cancelled && dbStatus.status() == STATUS_Pending) {
	dbHandle.cancelMoveRequest(&dbStatus);
    }

    if (dbStatus.status() == STATUS_Pending) {
        moveNextImage(&dbStatus);
    }

    if (dbStatus.status() != STATUS_Pending) {
	/*
	 * Tear down sub-association (if it exists).
	 */
	closeSubAssociation();

	/*
	 * Need to adjust the final status if any sub-operations failed or
	 * had warnings 
	 */
	if (nFailed > 0 || nWarning > 0) {
	    dbStatus.setStatus(STATUS_MOVE_Warning_SubOperationsCompleteOneOrMoreFailures);
	}
        /*
         * if all the sub-operations failed then we need to generate a failed or refused status.
         * cf. DICOM part 4, C.4.2.3.1
         * we choose to generate a "Refused - Out of Resources - Unable to perform suboperations" status.
         */
        if ((nFailed > 0) && ((nCompleted + nWarning) == 0)) {
	    dbStatus.setStatus(STATUS_MOVE_Refused_OutOfResourcesSubOperations);
	}
    }
    
    if (dbStatus.status() != STATUS_Success && 
        dbStatus.status() != STATUS_Pending) {
	/* 
	 * May only include response identifiers if not Success 
	 * and not Pending 
	 */
	buildFailedInstanceList(responseIdentifiers);
    }

    /* set response status */
    response->DimseStatus = dbStatus.status();
    response->NumberOfRemainingSubOperations = nRemaining;
    response->NumberOfCompletedSubOperations = nCompleted;
    response->NumberOfFailedSubOperations = nFailed;
    response->NumberOfWarningSubOperations = nWarning;
    *stDetail = dbStatus.extractStatusDetail();

    if (options_.verbose_) {
        printf("Move SCP Response %d [status: %s]\n", responseCount,
	    DU_cmoveStatusString(dbStatus.status()));
    }
    if (options_.verbose_ > 1) {
        DIMSE_printCMoveRSP(stdout, response);
        if (DICOM_PENDING_STATUS(dbStatus.status()) && (*responseIdentifiers != NULL)) {
            printf("Move SCP Response Identifiers:\n");
            (*responseIdentifiers)->print(COUT);
        }
        if (*stDetail) {
            printf("Status detail:\n");
            (*stDetail)->print(COUT);
        }
    }    
}

void DcmQueryRetrieveMoveContext::addFailedUIDInstance(const char *sopInstance)
{
    int len;

    if (failedUIDs == NULL) {
	if ((failedUIDs = (char*)malloc(DIC_UI_LEN+1)) == NULL) {
	    DcmQueryRetrieveOptions::errmsg("malloc failure: addFailedUIDInstance");
	    return;
	}
	strcpy(failedUIDs, sopInstance);
    } else {
	len = strlen(failedUIDs);
	if ((failedUIDs = (char*)realloc(failedUIDs, 
	    (len+strlen(sopInstance)+2))) == NULL) {
	    DcmQueryRetrieveOptions::errmsg("realloc failure: addFailedUIDInstance");
	    return;
	}
	/* tag sopInstance onto end of old with '\' between */
	strcat(failedUIDs, "\\");
	strcat(failedUIDs, sopInstance);
    }
}

OFCondition DcmQueryRetrieveMoveContext::performMoveSubOp(DIC_UI sopClass, DIC_UI sopInstance, char *fname)
{
    OFCondition cond = EC_Normal;
    T_DIMSE_C_StoreRQ req;
    T_DIMSE_C_StoreRSP rsp;
    DIC_US msgId;
    T_ASC_PresentationContextID presId;
    DcmDataset *stDetail = NULL;

#ifdef LOCK_IMAGE_FILES
    /* shared lock image file */
    int lockfd;
#ifdef O_BINARY
    lockfd = open(fname, O_RDONLY | O_BINARY, 0666);
#else
    lockfd = open(fname, O_RDONLY , 0666);
#endif
    if (lockfd < 0) {
        /* due to quota system the file could have been deleted */
	DcmQueryRetrieveOptions::errmsg("Move SCP: storeSCU: [file: %s]: %s", 
	    fname, strerror(errno));
	nFailed++;
	addFailedUIDInstance(sopInstance);
	return EC_Normal;
    }
    dcmtk_flock(lockfd, LOCK_SH);
#endif

    msgId = subAssoc->nextMsgID++;
 
    /* which presentation context should be used */
    presId = ASC_findAcceptedPresentationContextID(subAssoc,
        sopClass);
    if (presId == 0) {
	nFailed++;
	addFailedUIDInstance(sopInstance);
	DcmQueryRetrieveOptions::errmsg("Move SCP: storeSCU: [file: %s] No presentation context for: (%s) %s", 
	    fname, dcmSOPClassUIDToModality(sopClass), sopClass);
	return DIMSE_NOVALIDPRESENTATIONCONTEXTID;
    }

    req.MessageID = msgId;
    strcpy(req.AffectedSOPClassUID, sopClass);
    strcpy(req.AffectedSOPInstanceUID, sopInstance);
    req.DataSetType = DIMSE_DATASET_PRESENT;
    req.Priority = priority;
    req.opts = (O_STORE_MOVEORIGINATORAETITLE | O_STORE_MOVEORIGINATORID);
    strcpy(req.MoveOriginatorApplicationEntityTitle, origAETitle);
    req.MoveOriginatorID = origMsgId;

    if (options_.verbose_) {
	printf("Store SCU RQ: MsgID %d, (%s)\n", 
	    msgId, dcmSOPClassUIDToModality(sopClass));
    }

    cond = DIMSE_storeUser(subAssoc, presId, &req,
        fname, NULL, moveSubOpProgressCallback, this, 
	options_.blockMode_, options_.dimse_timeout_, 
	&rsp, &stDetail);
	
#ifdef LOCK_IMAGE_FILES
    /* unlock image file */
    dcmtk_flock(lockfd, LOCK_UN);
    close(lockfd);
#endif
	
    if (cond.good()) {
        if (options_.verbose_) {
	    printf("Move SCP: Received Store SCU RSP [Status=%s]\n",
	        DU_cstoreStatusString(rsp.DimseStatus));
        }
	if (rsp.DimseStatus == STATUS_Success) {
	    /* everything ok */
	    nCompleted++;
	} else if ((rsp.DimseStatus & 0xf000) == 0xb000) {
	    /* a warning status message */
	    nWarning++;
	    DcmQueryRetrieveOptions::errmsg("Move SCP: Store Waring: Response Status: %s", 
		DU_cstoreStatusString(rsp.DimseStatus));
	} else {
	    nFailed++;
	    addFailedUIDInstance(sopInstance);
	    /* print a status message */
	    DcmQueryRetrieveOptions::errmsg("Move SCP: Store Failed: Response Status: %s", 
		DU_cstoreStatusString(rsp.DimseStatus));
	}
    } else {
	nFailed++;
	addFailedUIDInstance(sopInstance);
	DcmQueryRetrieveOptions::errmsg("Move SCP: storeSCU: Store Request Failed:");
	DimseCondition::dump(cond);
    }
    if (stDetail != NULL) {
        if (options_.verbose_) {
	    printf("  Status Detail:\n");
	    stDetail->print(COUT);
	}
        delete stDetail;
    }
    return cond;
}

OFCondition DcmQueryRetrieveMoveContext::buildSubAssociation(T_DIMSE_C_MoveRQ *request)
{
    OFCondition cond = EC_Normal;
    DIC_NODENAME dstHostName;
    DIC_NODENAME dstHostNamePlusPort;
    int dstPortNumber;
    DIC_NODENAME localHostName;
    T_ASC_Parameters *params;

    strcpy(dstAETitle, request->MoveDestination);

    /*
     * We must map the destination AE Title into a host name and port
     * address.  Further, we must make sure that the RSNA'93 demonstration
     * rules are observed regarding move destinations. 
     */

    DIC_AE aeTitle;
    aeTitle[0] = '\0';
    ASC_getAPTitles(origAssoc->params, origAETitle, aeTitle, NULL);
    ourAETitle = aeTitle;

    ASC_getPresentationAddresses(origAssoc->params, origHostName, NULL);

    if (!mapMoveDestination(origHostName, origAETitle,
	request->MoveDestination, dstHostName, &dstPortNumber)) {
	return APP_INVALIDPEER;
    }
    if (cond.good()) {
	cond = ASC_createAssociationParameters(&params, ASC_DEFAULTMAXPDU);
	if (cond.bad()) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Cannot create Association-params for sub-ops:");
	    DimseCondition::dump(cond);
	}
    }
    if (cond.good()) {
	gethostname(localHostName, sizeof(localHostName) - 1);
	sprintf(dstHostNamePlusPort, "%s:%d", dstHostName, dstPortNumber);
	ASC_setPresentationAddresses(params, localHostName, 
		dstHostNamePlusPort);
	ASC_setAPTitles(params, ourAETitle.c_str(), dstAETitle,NULL);

	cond = addAllStoragePresentationContexts(params);
	if (cond.bad()) {
	    DimseCondition::dump(cond);
	}
	if (options_.debug_) {
	    printf("Request Parameters:\n");
	    ASC_dumpParameters(params, COUT);
	}
    }
    if (cond.good()) {
	/* create association */
	if (options_.verbose_)
	    printf("Requesting Sub-Association\n");
	cond = ASC_requestAssociation(options_.net_, params,
				      &subAssoc);
	if (cond.bad()) {
	    if (cond == DUL_ASSOCIATIONREJECTED) {
		T_ASC_RejectParameters rej;

		ASC_getRejectParameters(params, &rej);
		DcmQueryRetrieveOptions::errmsg("moveSCP: Sub-Association Rejected");
		ASC_printRejectParameters(stderr, &rej);
		fprintf(stderr, "\n");
	    } else {
		DcmQueryRetrieveOptions::errmsg("moveSCP: Sub-Association Request Failed:");
		DimseCondition::dump(cond);
		
	    }
	}
    }

    if (cond.good()) {
	assocStarted = OFTrue;
    }    
    return cond;
}

OFCondition DcmQueryRetrieveMoveContext::closeSubAssociation()
{
    OFCondition cond = EC_Normal;

    if (subAssoc != NULL) {
	/* release association */
	if (options_.verbose_)
	    printf("Releasing Sub-Association\n");
	cond = ASC_releaseAssociation(subAssoc);
	if (cond.bad()) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Sub-Association Release Failed:");
	    DimseCondition::dump(cond);
	}
	cond = ASC_dropAssociation(subAssoc);
	if (cond.bad()) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Sub-Association Drop Failed:");
	    DimseCondition::dump(cond);
	}
	cond = ASC_destroyAssociation(&subAssoc);
	if (cond.bad()) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Sub-Association Destroy Failed:");
	    DimseCondition::dump(cond);
	}

    }

    if (assocStarted) {
	assocStarted = OFFalse;
    }

    return cond;
}

void DcmQueryRetrieveMoveContext::moveNextImage(DcmQueryRetrieveDatabaseStatus * dbStatus)
{
    OFCondition cond = EC_Normal;
    OFCondition dbcond = EC_Normal;
    DIC_UI subImgSOPClass;	/* sub-operation image SOP Class */
    DIC_UI subImgSOPInstance;	/* sub-operation image SOP Instance */
    char subImgFileName[MAXPATHLEN + 1];	/* sub-operation image file */

    /* clear out strings */
    bzero(subImgFileName, sizeof(subImgFileName));
    bzero(subImgSOPClass, sizeof(subImgSOPClass));
    bzero(subImgSOPInstance, sizeof(subImgSOPInstance));

    /* get DB response */
    dbcond = dbHandle.nextMoveResponse(
	subImgSOPClass, subImgSOPInstance, subImgFileName,
	&nRemaining, dbStatus);
    if (dbcond.bad()) {
	DcmQueryRetrieveOptions::errmsg("moveSCP: Database: nextMoveResponse Failed (%s):",
	    DU_cmoveStatusString(dbStatus->status()));
    }

    if (dbStatus->status() == STATUS_Pending) {
	/* perform sub-op */
	cond = performMoveSubOp(subImgSOPClass,
	    subImgSOPInstance, subImgFileName);
	if (cond != EC_Normal) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Move Sub-Op Failed:");
	    DimseCondition::dump(cond);
	    	/* clear condition stack */
	}
    }
}

void DcmQueryRetrieveMoveContext::failAllSubOperations(DcmQueryRetrieveDatabaseStatus * dbStatus)
{
    OFCondition dbcond = EC_Normal;
    DIC_UI subImgSOPClass;	/* sub-operation image SOP Class */
    DIC_UI subImgSOPInstance;	/* sub-operation image SOP Instance */
    char subImgFileName[MAXPATHLEN + 1];	/* sub-operation image file */

    /* clear out strings */
    bzero(subImgFileName, sizeof(subImgFileName));
    bzero(subImgSOPClass, sizeof(subImgSOPClass));
    bzero(subImgSOPInstance, sizeof(subImgSOPInstance));

    while (dbStatus->status() == STATUS_Pending) {
        /* get DB response */
        dbcond = dbHandle.nextMoveResponse(
	    subImgSOPClass, subImgSOPInstance, subImgFileName,
	    &nRemaining, dbStatus);
        if (dbcond.bad()) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: Database: nextMoveResponse Failed (%s):",
	        DU_cmoveStatusString(dbStatus->status()));
        }

	if (dbStatus->status() == STATUS_Pending) {
	    nFailed++;
	    addFailedUIDInstance(subImgSOPInstance);
	}
    }
    dbStatus->setStatus(STATUS_MOVE_Warning_SubOperationsCompleteOneOrMoreFailures);    
}

void DcmQueryRetrieveMoveContext::buildFailedInstanceList(DcmDataset ** rspIds)
{
    OFBool ok;

    if (failedUIDs != NULL) {
	*rspIds = new DcmDataset();
	ok = DU_putStringDOElement(*rspIds, DCM_FailedSOPInstanceUIDList,
	    failedUIDs);
	if (!ok) {
	    DcmQueryRetrieveOptions::errmsg("moveSCP: failed to build DCM_FailedSOPInstanceUIDList");
	}
	free(failedUIDs);
	failedUIDs = NULL;
    }
}

OFBool DcmQueryRetrieveMoveContext::mapMoveDestination(
  const char *origPeer, const char *origAE,
  const char *dstAE, char *dstPeer, int *dstPort)
{
    /*
     * This routine enforces RSNA'93 Demo Requirements regarding
     * the destination of move commands.
     * 
     */
    OFBool ok = OFFalse;
    const char *dstPeerName; /* the CNF utility returns us a static char* */

    if (options_.restrictMoveToSameAE_) {
        /* AE Titles the same ? */
        ok = (strcmp(origAE, dstAE) == 0);
        if (!ok) {
	    if (options_.verbose_) {
	        printf("mapMoveDestination: strictMove Reqs: '%s' != '%s'\n",
		    origAE, dstAE); 
	    }
	    return OFFalse;
	}
    }
    
    ok = config->peerForAETitle((char*)dstAE, &dstPeerName, dstPort) > 0;
    if (!ok) {
        if (options_.verbose_) {
	    printf("mapMoveDestination: unknown AE: '%s'\n", dstAE);
	}
        return OFFalse;	/* dstAE not known */
    }
    
    strcpy(dstPeer, dstPeerName);

    if (options_.restrictMoveToSameHost_) {
	/* hosts the same ? */
	ok = (strcmp(origPeer, dstPeer) == 0);
	if (!ok) {
	    if (options_.verbose_) {
		printf("mapMoveDestination: different hosts: '%s', '%s'\n",
		       origPeer, dstPeer);
	    }
	    return OFFalse;
	}
    }

    if (options_.restrictMoveToSameVendor_) {
	/* AE titles belong to the same vendor */
	ok = config->checkForSameVendor((char*)origAE, (char*)dstAE) > 0;
	if (!ok) {
	    if (options_.verbose_) {
		printf("mapMoveDestination: different vendors: '%s', '%s'\n",
		       origAE, dstAE);
	    }
	    return OFFalse;
	}
    }
    
    return ok;
}

OFCondition DcmQueryRetrieveMoveContext::addAllStoragePresentationContexts(T_ASC_Parameters *params)
{
    // this would be the place to add support for compressed transfer syntaxes
    OFCondition cond = EC_Normal;

    int i;
    int pid = 1;

    const char* transferSyntaxes[] = { NULL, NULL, NULL, NULL };
    int numTransferSyntaxes = 0;

#ifdef DISABLE_COMPRESSION_EXTENSION
    /* gLocalByteOrder is defined in dcxfer.h */
    if (gLocalByteOrder == EBO_LittleEndian) {
    /* we are on a little endian machine */
        transferSyntaxes[0] = UID_LittleEndianExplicitTransferSyntax;
        transferSyntaxes[1] = UID_BigEndianExplicitTransferSyntax;
        transferSyntaxes[2] = UID_LittleEndianImplicitTransferSyntax;
        numTransferSyntaxes = 3;
    } else {
        /* we are on a big endian machine */
        transferSyntaxes[0] = UID_BigEndianExplicitTransferSyntax;
        transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
        transferSyntaxes[2] = UID_LittleEndianImplicitTransferSyntax;
        numTransferSyntaxes = 3;
    }
#else
    switch (options_.networkTransferSyntaxOut_)
    {
      case EXS_LittleEndianImplicit:
        /* we only support Little Endian Implicit */
        transferSyntaxes[0]  = UID_LittleEndianImplicitTransferSyntax;
        numTransferSyntaxes = 1;
        break;
      case EXS_LittleEndianExplicit:
        /* we prefer Little Endian Explicit */
        transferSyntaxes[0] = UID_LittleEndianExplicitTransferSyntax;
        transferSyntaxes[1] = UID_BigEndianExplicitTransferSyntax;
        transferSyntaxes[2]  = UID_LittleEndianImplicitTransferSyntax;
        numTransferSyntaxes = 3;
        break;
      case EXS_BigEndianExplicit:
        /* we prefer Big Endian Explicit */
        transferSyntaxes[0] = UID_BigEndianExplicitTransferSyntax;
        transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
        transferSyntaxes[2]  = UID_LittleEndianImplicitTransferSyntax;
        numTransferSyntaxes = 3;
        break;
    case EXS_JPEGProcess14SV1TransferSyntax:
      /* we prefer JPEGLossless:Hierarchical-1stOrderPrediction (default lossless) */
      transferSyntaxes[0] = UID_JPEGProcess14SV1TransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
    case EXS_JPEGProcess1TransferSyntax:
      /* we prefer JPEGBaseline (default lossy for 8 bit images) */
      transferSyntaxes[0] = UID_JPEGProcess1TransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
    case EXS_JPEGProcess2_4TransferSyntax:
      /* we prefer JPEGExtended (default lossy for 12 bit images) */
      transferSyntaxes[0] = UID_JPEGProcess2_4TransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
    case EXS_JPEG2000LosslessOnly:
      /* we prefer JPEG 2000 lossless */
      transferSyntaxes[0] = UID_JPEG2000LosslessOnlyTransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
    case EXS_JPEG2000:
      /* we prefer JPEG 2000 lossy or lossless */
      transferSyntaxes[0] = UID_JPEG2000TransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
#ifdef WITH_ZLIB
    case EXS_DeflatedLittleEndianExplicit:
      /* we prefer deflated transmission */
      transferSyntaxes[0] = UID_DeflatedExplicitVRLittleEndianTransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
#endif
    case EXS_RLELossless:
      /* we prefer RLE Lossless */
      transferSyntaxes[0] = UID_RLELosslessTransferSyntax;
      transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
      transferSyntaxes[2] = UID_BigEndianExplicitTransferSyntax;
      transferSyntaxes[3] = UID_LittleEndianImplicitTransferSyntax;
      numTransferSyntaxes = 4;
      break;
    default:
        /* We prefer explicit transfer syntaxes.
         * If we are running on a Little Endian machine we prefer
         * LittleEndianExplicitTransferSyntax to BigEndianTransferSyntax.
         */
        if (gLocalByteOrder == EBO_LittleEndian)  /* defined in dcxfer.h */
        {
          transferSyntaxes[0] = UID_LittleEndianExplicitTransferSyntax;
          transferSyntaxes[1] = UID_BigEndianExplicitTransferSyntax;
        } else {
          transferSyntaxes[0] = UID_BigEndianExplicitTransferSyntax;
          transferSyntaxes[1] = UID_LittleEndianExplicitTransferSyntax;
        }
        transferSyntaxes[2] = UID_LittleEndianImplicitTransferSyntax;
        numTransferSyntaxes = 3;
        break;
    }
#endif
        
    for (i=0; i<numberOfDcmLongSCUStorageSOPClassUIDs && cond.good(); i++) {
	cond = ASC_addPresentationContext(
	    params, pid, dcmLongSCUStorageSOPClassUIDs[i],
	    transferSyntaxes, numTransferSyntaxes);
	pid += 2;	/* only odd presentation context id's */
    }
    return cond;
}


/*
 * CVS Log
 * $Log: dcmqrcbm.cc,v $
 * Revision 1.1  2006/03/01 20:16:07  lpysher
 * Added dcmtkt ocvs not in xcode  and fixed bug with multiple monitors
 *
 * Revision 1.9  2005/12/20 11:21:30  meichel
 * Removed duplicate parameter
 *
 * Revision 1.8  2005/12/08 15:47:06  meichel
 * Changed include path schema for all DCMTK header files
 *
 * Revision 1.7  2005/11/29 10:54:52  meichel
 * Added minimal support for compressed transfer syntaxes to dcmqrscp.
 *   No on-the-fly decompression is performed, but compressed images can
 *   be stored and retrieved.
 *
 * Revision 1.6  2005/11/17 13:44:40  meichel
 * Added command line options for DIMSE and ACSE timeouts
 *
 * Revision 1.5  2005/10/25 08:56:18  meichel
 * Updated list of UIDs and added support for new transfer syntaxes
 *   and storage SOP classes.
 *
 * Revision 1.4  2005/08/30 08:37:52  meichel
 * Fixed syntax error reported by Visual Studio 2003
 *
 * Revision 1.3  2005/06/16 08:02:43  meichel
 * Added system include files needed on Solaris
 *
 * Revision 1.2  2005/04/04 14:39:54  meichel
 * Fixed warning on Win32 platform
 *
 * Revision 1.1  2005/03/30 13:34:53  meichel
 * Initial release of module dcmqrdb that will replace module imagectn.
 *   It provides a clear interface between the Q/R DICOM front-end and the
 *   database back-end. The imagectn code has been re-factored into a minimal
 *   class structure.
 *
 *
 */