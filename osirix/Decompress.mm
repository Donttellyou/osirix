#import <Foundation/Foundation.h>
#import <OsiriX/DCMObject.h>
#import <OsiriX/DCMTransferSyntax.h>
#import <OsiriX/DCMPixelDataAttribute.h>
#import "DefaultsOsiriX.h"

#undef verify
#include "osconfig.h" /* make sure OS specific configuration is included first */
#include "djdecode.h"  /* for dcmjpeg decoders */
#include "djencode.h"  /* for dcmjpeg encoders */
#include "dcrledrg.h"  /* for DcmRLEDecoderRegistration */
#include "dcrleerg.h"  /* for DcmRLEEncoderRegistration */
#include "djrploss.h"
#include "djrplol.h"
#include "dcpixel.h"
#include "dcrlerp.h"

#include "dcdatset.h"
#include "dcmetinf.h"
#include "dcfilefo.h"
#include "dcdebug.h"
#include "dcuid.h"
#include "dcdict.h"
#include "dcdeftag.h"

extern void dcmtkSetJPEGColorSpace( int);

// WHY THIS EXTERNAL APPLICATION FOR COMPRESS OR DECOMPRESSION?

// Because if a file is corrupted, it will not crash the OsiriX application, but only this small task.

int main(int argc, const char *argv[])
{
	NSAutoreleasePool	*pool	= [[NSAutoreleasePool alloc] init];
	
	//	argv[ 1] : in path
	//	argv[ 2] : out path
	//	argv[ 2] : what? compress or decompress?
	
	if( argv[ 1] && argv[ 2])
	{
		// register global JPEG decompression codecs
		DJDecoderRegistration::registerCodecs();

		// register global JPEG compression codecs
		DJEncoderRegistration::registerCodecs(
			ECC_lossyYCbCr,
			EUC_default,
			OFFalse,
			OFFalse,
			0,
			0,
			0,
			OFTrue,
			ESS_444,
			OFFalse,
			OFFalse,
			0,
			0,
			0.0,
			0.0,
			0,
			0,
			0,
			0,
			OFTrue,
			OFFalse,
			OFFalse,
			OFFalse,
			OFTrue);

		// register RLE compression codec
		DcmRLEEncoderRegistration::registerCodecs();

		// register RLE decompression codec
		DcmRLEDecoderRegistration::registerCodecs();
	
		NSString	*path = [NSString stringWithCString:argv[ 1]];
		NSString	*what = [NSString stringWithCString:argv[ 2]];
		NSString	*dest = nil;
		
		if(argv[ 3]) dest = [NSString stringWithCString:argv[ 3]];
		
		if( [what isEqualToString:@"compressJPEG2000"])
		{
			OFCondition cond;
			OFBool status = YES;
			const char *fname = (const char *)[path UTF8String];
			const char *destination = nil;
			
			if( dest && [dest isEqualToString:path] == NO) destination = (const char *)[dest UTF8String];
			else
			{
				dest = path;
				destination = fname;
			}
			
			NSMutableDictionary	*dict = [DefaultsOsiriX getDefaults];
			[dict addEntriesFromDictionary: [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.rossetantoine.osirix"]];
			
			dcmtkSetJPEGColorSpace( [[dict objectForKey:@"UseJPEGColorSpace"] intValue]);
			[DCMPixelDataAttribute setUseOpenJpeg: [[dict objectForKey:@"UseOpenJpegForJPEG2000"] intValue]];
			int quality = [[dict objectForKey:@"JPEG2000quality"] intValue];
			
			DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile: path decodingPixelData:YES];
			[dcmObject writeToFile: [dest stringByAppendingString: @" temp"] withTransferSyntax:[DCMTransferSyntax JPEG2000LosslessTransferSyntax] quality: quality AET:@"OsiriX" atomically:YES];
			[dcmObject release];
			
			if( dest == path)
				[[NSFileManager defaultManager] removeFileAtPath: path handler: nil];
			[[NSFileManager defaultManager] movePath: [dest stringByAppendingString: @" temp"]  toPath: dest handler: nil];
		}
		
		if( [what isEqualToString:@"compress"])
		{
			OFCondition cond;
			OFBool status = YES;
			const char *fname = (const char *)[path UTF8String];
			const char *destination = nil;
			
			if( dest && [dest isEqualToString:path] == NO) destination = (const char *)[dest UTF8String];
			else
			{
				dest = path;
				destination = fname;
			}
			
			DcmFileFormat fileformat;
			cond = fileformat.loadFile(fname);
			// if we can't read it stop
			if (!cond.good())
				return NO;
			E_TransferSyntax tSyntax = EXS_JPEGProcess14SV1TransferSyntax;
			DcmDataset *dataset = fileformat.getDataset();
			DcmItem *metaInfo = fileformat.getMetaInfo();
			DcmXfer original_xfer(dataset->getOriginalXfer());
			if (original_xfer.isEncapsulated())
			{
				NSLog( @"file already compressed: %@", [path lastPathComponent]);
				return 1;
			}
			DJ_RPLossless losslessParams(6,0); 
			//DJ_RPLossy lossyParams(0.8);
			//DcmRLERepresentationParameter rleParams;
			// Use fixed lossless for now
			DcmRepresentationParameter *params = &losslessParams;
			
			/*
				DJ_RPLossless losslessParams; // codec parameters, we use the defaults
				if (transferSyntax == EXS_JPEGProcess14SV1TransferSyntax)
				params = &losslessParams;
				else if (transferSyntax == EXS_JPEGProcess2_4TransferSyntax)
				params = &lossyParams; 
				else if (transferSyntax == EXS_RLELossless)
				params = &rleParams; 
			*/

			// this causes the lossless JPEG version of the dataset to be created
			DcmXfer oxferSyn(tSyntax);
			dataset->chooseRepresentation(tSyntax, params);
			// check if everything went well
			if (dataset->canWriteXfer(tSyntax))
			{
				// force the meta-header UIDs to be re-generated when storing the file 
				// since the UIDs in the data set may have changed 
				
				//only need to do this for lossy
				delete metaInfo->remove(DCM_MediaStorageSOPClassUID);
				delete metaInfo->remove(DCM_MediaStorageSOPInstanceUID);
				
				// store in lossless JPEG format
				fileformat.loadAllDataIntoMemory();
				if( dest == path) [[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithCString:fname] handler:nil];
				
				cond = fileformat.saveFile(destination, tSyntax);
				status =  (cond.good()) ? YES : NO;
			}
			else
				status = NO;
		}
		
		if( [what isEqualToString:@"decompress"])
		{
			NSMutableDictionary	*dict = [DefaultsOsiriX getDefaults];
			[dict addEntriesFromDictionary: [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.rossetantoine.osirix"]];
			
			dcmtkSetJPEGColorSpace( [[dict objectForKey:@"UseJPEGColorSpace"] intValue]);
			
			OFCondition cond;
			OFBool status = YES;
			const char *fname = (const char *)[path UTF8String];
			
			const char *destination = nil;
			
			if( dest) destination = (const char *)[dest UTF8String];
			else
			{
				dest = path;
				destination = fname;
			}
			
			DcmFileFormat fileformat;
			cond = fileformat.loadFile(fname);
			DcmXfer filexfer(fileformat.getDataset()->getOriginalXfer());
			
			//hopefully dcmtk willsupport jpeg2000 compression and decompression in the future
			
			if (filexfer.getXfer() == EXS_JPEG2000LosslessOnly || filexfer.getXfer() == EXS_JPEG2000)
			{
				[DCMPixelDataAttribute setUseOpenJpeg: [[dict objectForKey:@"UseOpenJpegForJPEG2000"] intValue]];
				DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile:path decodingPixelData:YES];
				
				[dcmObject writeToFile:[path stringByAppendingString:@" temp"] withTransferSyntax:[DCMTransferSyntax ImplicitVRLittleEndianTransferSyntax] quality:1 AET:@"OsiriX" atomically:YES];
				
				[dcmObject release];
				
				if( dest == path) [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
				
				[[NSFileManager defaultManager] movePath:[path stringByAppendingString:@" temp"] toPath:dest handler: nil];
			}
			else if (filexfer.getXfer() != EXS_LittleEndianExplicit)
			{
				DcmDataset *dataset = fileformat.getDataset();
				
				// decompress data set if compressed
				dataset->chooseRepresentation(EXS_LittleEndianExplicit, NULL);
				
				// check if everything went well
				if (dataset->canWriteXfer(EXS_LittleEndianExplicit))
				{
					fileformat.loadAllDataIntoMemory();
					if( dest == path) [[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithCString:fname] handler:nil];
					cond = fileformat.saveFile(destination, EXS_LittleEndianExplicit);
					status =  (cond.good()) ? YES : NO;
				}
				else status = NO;
			}
			
			if( status == NO) NSLog(@"decompress error");
		}
		
	    // deregister JPEG codecs
		DJDecoderRegistration::cleanup();
		DJEncoderRegistration::cleanup();

		// deregister RLE codecs
		DcmRLEDecoderRegistration::cleanup();
		DcmRLEEncoderRegistration::cleanup();
	}
	
//	[pool release]; We dont care: we are just a small app : our memory will be killed by the system. Dont loose time here !
	
	return 0;
}
